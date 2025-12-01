package main

import (
	"context"
	"encoding/json"
	"fmt"
	"reflect"

	xfnproto "github.com/crossplane/function-sdk-go/proto/v1"
	"github.com/crossplane/function-sdk-go/resource/composite"
	corev1 "k8s.io/api/core/v1"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

// Register services for the PoC.
func RegisterServices(m *Manager) {
	RegisterService("redis-poc", Service[*composite.Unstructured]{
		Steps: []Step[*composite.Unstructured]{
			{
				Name: "bootstrap",
				Execute: func(ctx context.Context, _ *composite.Unstructured, svc *ServiceRuntime) *xfnproto.Result {
					// 1. Create state with descriptors
					state := newRedisState()
					// 2. Load observed state from cluster
					svc.ObserveState(state)
					// 3. Build desired resources using observed data + config
					buildRedisDesired(state, svc)
					// 4. Apply desired resources to Crossplane
					svc.ApplyState(state)
					// 5. Export connection details
					setRedisConnectionDetails(state, svc)
					return nil
				},
			},
		},
	})
}

// redisResources represents the set of Kubernetes resources for a Redis instance
type redisResources struct {
	Namespace *corev1.Namespace
	Secret    *corev1.Secret
	Helm      client.Object // Can be *helmv1.Release (desired) or *composed.Unstructured (observed)
}

// redisState uses BaseState for automatic Desired() and SetObserved()
type redisState = BaseState[redisResources]

// newRedisState creates a new Redis state with resource descriptors
func newRedisState() *redisState {
	return NewBaseState[redisResources]([]ResourceDescriptor{
		{Name: "namespace", Type: reflect.TypeOf(&corev1.Namespace{})},
		{Name: "redis-secret", Type: reflect.TypeOf(&corev1.Secret{}), Optional: true},
		{Name: "helmrelease", Type: nil}, // nil = keep as Unstructured for status
	})
}

// buildRedisDesired builds desired resources using observed state and config
func buildRedisDesired(state *redisState, svc *ServiceRuntime) {
	cfg := svc.Config()
	chartRepo := cfg["chartRepository"]
	if chartRepo == "" {
		chartRepo = "https://charts.bitnami.com/bitnami"
	}
	chartVersion := cfg["chartVersion"]
	if chartVersion == "" {
		chartVersion = "18.0.0"
	}

	// Derive instance-specific names from composite resource name, later these can be templated in KCL
	compositeName := svc.desiredComposite.GetName()
	targetNamespace := fmt.Sprintf("vshn-redis-%s", compositeName)
	secretName := fmt.Sprintf("%s-helm-secret", compositeName)

	// 1. Create namespace for Redis instance
	ns := NewNamespaceBuilder(targetNamespace).
		WithLabel("app.kubernetes.io/managed-by", "crossplane").
		WithLabel("app.kubernetes.io/part-of", "redis-poc").
		Build()

	// 2. Create or reuse secret with password
	var password string
	if state.observed.Secret != nil {
		// Reuse existing password from observed secret
		password = string(state.observed.Secret.Data["password"])
	} else {
		// Generate new password (will be created on first run)
		password = "" // SecretBuilder will generate it
	}

	secret := NewSecretBuilder(secretName, targetNamespace).
		WithLabel("app.kubernetes.io/managed-by", "crossplane").
		WithLabel("app.kubernetes.io/part-of", "redis-poc")

	if password != "" {
		// Use existing password
		secret.WithStringData("password", password)
	} else {
		// Generate new random password
		secret.WithRandomPassword("password", 16)
	}

	// 3. Create HelmRelease with values from config + template rendering
	// Check if helmValuesTemplate exists in config (future KCL addition)
	var helmValues map[string]any
	if helmValuesTemplate, ok := cfg["helmValuesTemplate"]; ok {
		// Render template with runtime values
		renderedJSON := RenderTemplate(helmValuesTemplate, map[string]string{
			"__SECRET_NAME__": secretName,
			"__NAMESPACE__":   targetNamespace,
		})
		// Parse rendered JSON into map
		if err := json.Unmarshal([]byte(renderedJSON), &helmValues); err != nil {
			svc.AddResult(NewFatalResult(fmt.Errorf("failed to parse helmValuesTemplate: %w", err)))
			return
		}
	} else {
		// Fallback to hardcoded values (for now, until KCL template is added)
		helmValues = ValuesFromConfig(cfg, map[string]any{
			"auth": map[string]any{
				"enabled":        true,
				"existingSecret": secretName,
			},
			"networkPolicy": map[string]any{"enabled": true},
		})
	}

	helm := NewHelmReleaseBuilder("redis-poc").
		WithChart(chartRepo, "redis", chartVersion).
		WithTargetNamespace(targetNamespace).
		WithValues(helmValues).
		Build()

	// Set desired resources in state
	state.desired.Namespace = ns
	state.desired.Secret = secret.Build()
	state.desired.Helm = helm
}

// setRedisConnectionDetails exports connection details for the Redis instance
func setRedisConnectionDetails(state *redisState, svc *ServiceRuntime) {
	// Only export if Secret is ready (has been observed)
	if state.observed.Secret == nil {
		return
	}

	// Derive instance-specific namespace from composite resource name
	compositeName := svc.desiredComposite.GetName()
	targetNamespace := fmt.Sprintf("vshn-redis-%s", compositeName)
	password := state.observed.Secret.Data["password"]

	// Export standard Redis connection details
	svc.SetConnectionDetailString("REDIS_HOST", "redis-poc-master."+targetNamespace+".svc")
	svc.SetConnectionDetailString("REDIS_PORT", "6379")
	svc.SetConnectionDetailString("REDIS_USERNAME", "default")
	svc.SetConnectionDetail("REDIS_PASSWORD", password)
	svc.SetConnectionDetailString("REDIS_URL", "redis://default:"+string(password)+"@redis-poc-master."+targetNamespace+".svc:6379")
}
