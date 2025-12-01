package main

import (
	"context"
	"encoding/json"
	"fmt"
	"reflect"
	"strings"

	fnv1 "github.com/crossplane/function-sdk-go/proto/v1"
	xfnproto "github.com/crossplane/function-sdk-go/proto/v1"
	"github.com/crossplane/function-sdk-go/request"
	"github.com/crossplane/function-sdk-go/resource"
	"github.com/crossplane/function-sdk-go/resource/composed"
	"github.com/crossplane/function-sdk-go/resource/composite"
	"github.com/crossplane/function-sdk-go/response"
	"github.com/go-logr/logr"
	"github.com/pkg/errors"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

// Register core scheme for composed.From
func init() {
	_ = corev1.AddToScheme(composed.Scheme)
}

// Steps and services

type Step[T client.Object] struct {
	Name    string
	Execute func(context.Context, T, *ServiceRuntime) *xfnproto.Result
}

type Service[T client.Object] struct {
	Steps []Step[T]
}

var serviceRegistry = map[string]any{}

func RegisterService[T client.Object](name string, svc Service[T]) {
	serviceRegistry[name] = svc
}

// Manager

type Manager struct {
	logr logr.Logger
	fnv1.UnimplementedFunctionRunnerServiceServer
}

func NewManager(log logr.Logger) *Manager { return &Manager{logr: log} }

// ServiceRuntime

type ServiceRuntime struct {
	Log               logr.Logger
	req               *fnv1.RunFunctionRequest
	resp              *fnv1.RunFunctionResponse
	config            map[string]string
	desiredResources  map[resource.Name]*resource.DesiredComposed
	observedResources map[resource.Name]resource.ObservedComposed
	desiredComposite  *composite.Unstructured
	observedComposite *composite.Unstructured
	results           []*xfnproto.Result
	gvk               schema.GroupVersionKind
	inputConfig       *corev1.ConfigMap
	connectionDetails map[string][]byte
}

func NewServiceRuntime(log logr.Logger, cfg *corev1.ConfigMap, req *fnv1.RunFunctionRequest) (*ServiceRuntime, error) {
	desiredResources, err := request.GetDesiredComposedResources(req)
	if err != nil {
		return nil, err
	}
	observedResources, err := request.GetObservedComposedResources(req)
	if err != nil {
		return nil, err
	}
	desiredComposite, err := request.GetDesiredCompositeResource(req)
	if err != nil {
		return nil, err
	}
	observedComposite, err := request.GetObservedCompositeResource(req)
	if err != nil {
		return nil, err
	}
	l := log.WithValues("resource", observedComposite.Resource.GetName())
	if cfg == nil {
		cfg = &corev1.ConfigMap{}
	}
	return &ServiceRuntime{
		Log:               l,
		req:               req,
		config:            cfg.Data,
		desiredResources:  desiredResources,
		observedResources: observedResources,
		desiredComposite:  desiredComposite.Resource,
		observedComposite: observedComposite.Resource,
		results:           []*xfnproto.Result{},
		gvk:               observedComposite.Resource.GetObjectKind().GroupVersionKind(),
		inputConfig:       cfg,
		connectionDetails: make(map[string][]byte),
	}, nil
}

// Response assembly.
func (s *ServiceRuntime) GetResponse() (*fnv1.RunFunctionResponse, error) {
	if s.resp != nil {
		return s.resp, nil
	}
	resp := response.To(s.req, response.DefaultTTL)
	if err := response.SetDesiredComposedResources(resp, s.desiredResources); err != nil {
		return nil, err
	}
	comp, err := request.GetDesiredCompositeResource(s.req)
	if err != nil {
		return nil, err
	}
	if s.desiredComposite != nil {
		if err := s.desiredComposite.SetValue("spec", nil); err != nil {
			return nil, err
		}
		comp.Resource = s.desiredComposite
	}
	if err := response.SetDesiredCompositeResource(resp, comp); err != nil {
		return nil, err
	}
	// Set connection details on the composite resource
	if len(s.connectionDetails) > 0 {
		if resp.Desired == nil {
			resp.Desired = &fnv1.State{}
		}
		if resp.Desired.Composite == nil {
			resp.Desired.Composite = &fnv1.Resource{}
		}
		resp.Desired.Composite.ConnectionDetails = s.connectionDetails
	}
	resp.Results = append(resp.Results, s.results...)
	return resp, nil
}

func (s *ServiceRuntime) AddResult(r *xfnproto.Result) { s.results = append(s.results, r) }

// State management

type DesiredResource struct {
	Name     string
	Object   client.Object
	Optional bool
}

type ServiceState interface {
	Desired() []DesiredResource
	SetObserved(map[resource.Name]resource.ObservedComposed) error
}

// ResourceDescriptor describes how to handle a resource in state
type ResourceDescriptor struct {
	Name     string      // Resource key name
	Optional bool        // Whether resource is optional
	Type     reflect.Type // Type for conversion (nil = keep as Unstructured)
}

// BaseState provides generic state management with automatic Desired() and SetObserved()
type BaseState[T any] struct {
	observed    T
	desired     T
	descriptors []ResourceDescriptor
}

// NewBaseState creates a new base state with resource descriptors
func NewBaseState[T any](descriptors []ResourceDescriptor) *BaseState[T] {
	return &BaseState[T]{descriptors: descriptors}
}

// Desired converts struct fields to DesiredResource array
func (b *BaseState[T]) Desired() []DesiredResource {
	resources := make([]DesiredResource, 0, len(b.descriptors))
	val := reflect.ValueOf(&b.desired).Elem()

	for i, desc := range b.descriptors {
		field := val.Field(i)
		if field.IsNil() {
			if !desc.Optional {
				continue
			}
		}

		if !field.IsNil() {
			obj := field.Interface().(client.Object)
			resources = append(resources, DesiredResource{
				Name:     desc.Name,
				Object:   obj,
				Optional: desc.Optional,
			})
		}
	}
	return resources
}

// SetObserved populates observed struct from Crossplane observed resources
func (b *BaseState[T]) SetObserved(obs map[resource.Name]resource.ObservedComposed) error {
	val := reflect.ValueOf(&b.observed).Elem()

	for i, desc := range b.descriptors {
		if o, ok := obs[resource.Name(desc.Name)]; ok {
			field := val.Field(i)

			// If Type is nil, keep as Unstructured
			if desc.Type == nil {
				field.Set(reflect.ValueOf(o.Resource))
				continue
			}

			// Convert to typed object
			typed := reflect.New(desc.Type.Elem()).Interface().(client.Object)
			if err := runtime.DefaultUnstructuredConverter.FromUnstructured(
				o.Resource.UnstructuredContent(), typed); err == nil {
				field.Set(reflect.ValueOf(typed))
			}
		}
	}
	return nil
}

func (s *ServiceRuntime) ApplyState(state ServiceState) {
	for _, d := range state.Desired() {
		if d.Object == nil {
			if d.Optional {
				continue
			}
			s.AddResult(NewFatalResult(fmt.Errorf("desired resource %s missing object", d.Name)))
			return
		}
		cmp, err := composed.From(runtime.Object(d.Object))
		if err != nil {
			s.AddResult(NewFatalResult(err))
			return
		}
		s.desiredResources[resource.Name(d.Name)] = &resource.DesiredComposed{Resource: cmp}
	}
}

func (s *ServiceRuntime) ObserveState(state ServiceState) {
	// Use pre-loaded observed resources from NewServiceRuntime
	_ = state.SetObserved(s.observedResources)
}

// Helpers to access composite and config
func (s *ServiceRuntime) GetObservedComposite(obj client.Object) error {
	comp, err := request.GetObservedCompositeResource(s.req)
	if err != nil {
		return err
	}
	b, err := comp.Resource.MarshalJSON()
	if err != nil {
		return err
	}
	return json.Unmarshal(b, obj)
}

func (s *ServiceRuntime) Config() map[string]string { return s.config }

// RenderTemplate replaces __PLACEHOLDER__ with values from context.
// This enables KCL ConfigMap templates to use placeholders that are
// replaced with runtime-derived values from the Go function.
//
// Example:
//   template := `{"auth": {"existingSecret": "__SECRET_NAME__"}}`
//   ctx := map[string]string{"__SECRET_NAME__": "my-instance-helm-secret"}
//   result := RenderTemplate(template, ctx)
//   // result: {"auth": {"existingSecret": "my-instance-helm-secret"}}
func RenderTemplate(template string, ctx map[string]string) string {
	result := template
	for key, value := range ctx {
		result = strings.ReplaceAll(result, key, value)
	}
	return result
}

// Connection details helpers
func (s *ServiceRuntime) SetConnectionDetail(key string, value []byte) {
	s.connectionDetails[key] = value
}

func (s *ServiceRuntime) SetConnectionDetailString(key, value string) {
	s.SetConnectionDetail(key, []byte(value))
}

// Manager.RunFunction
func (m *Manager) RunFunction(ctx context.Context, req *fnv1.RunFunctionRequest) (*fnv1.RunFunctionResponse, error) {
	errResp := response.To(req, response.DefaultTTL)

	// Input ConfigMap via inputRef
	cfg := &corev1.ConfigMap{}
	if err := request.GetInput(req, cfg); err != nil {
		return errResp, errors.Wrapf(err, "cannot get Function input from %T", req)
	}

	svcName, ok := cfg.Data["serviceName"]
	if !ok {
		return errResp, fmt.Errorf("input missing serviceName")
	}
	fn, found := serviceRegistry[svcName]
	if !found {
		return errResp, fmt.Errorf("service not found: %s", svcName)
	}
	sr, err := NewServiceRuntime(m.logr, cfg, req)
	if err != nil {
		return errResp, err
	}
	ctx = ctrl.LoggerInto(ctx, sr.Log)
	for _, step := range m.extractSteps(fn) {
		res := m.executeStep(ctx, sr, step)
		if res == nil {
			res = NewNormalResult(fmt.Sprintf("%s step ok", m.getStepName(step)))
		}
		sr.AddResult(res)
	}
	return sr.GetResponse()
}

func (m *Manager) extractSteps(service any) []any {
	v := reflect.ValueOf(service).Field(0)
	values := make([]any, v.Len())
	for i := 0; i < v.Len(); i++ {
		values[i] = v.Index(i).Interface()
	}
	return values
}

func (m *Manager) getStepName(step any) string { return reflect.ValueOf(step).Field(0).String() }

func (m *Manager) executeStep(ctx context.Context, sr *ServiceRuntime, step any) *xfnproto.Result {
	v := reflect.ValueOf(step).Field(1)
	co := &composite.Unstructured{}
	res := v.Call([]reflect.Value{reflect.ValueOf(ctx), reflect.ValueOf(co), reflect.ValueOf(sr)})
	if res[0].IsNil() {
		return nil
	}
	return res[0].Interface().(*xfnproto.Result)
}

func NewFatalResult(err error) *xfnproto.Result {
	return &xfnproto.Result{Severity: xfnproto.Severity_SEVERITY_FATAL, Message: err.Error()}
}

func NewNormalResult(msg string) *xfnproto.Result {
	return &xfnproto.Result{Severity: xfnproto.Severity_SEVERITY_NORMAL, Message: msg}
}
