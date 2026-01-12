package main

import (
	"fmt"

	"github.com/crossplane/crossplane-runtime/pkg/fieldpath"
	fnv1 "github.com/crossplane/function-sdk-go/proto/v1"
	"github.com/go-logr/logr"
	"google.golang.org/protobuf/types/known/structpb"
)

// extractUserSpec extracts user-provided spec from the composite resource
// Returns a map with the full spec (e.g., {size: {cpu: "1000m"}, replicas: 3})
func extractUserSpec(composite *fnv1.Resource) (map[string]any, error) {
	compositeMap := composite.Resource.AsMap()
	paved := fieldpath.Pave(compositeMap)

	specRaw, err := paved.GetValue("spec")
	if err != nil {
		return nil, fmt.Errorf("failed to get spec from composite: %w", err)
	}

	spec, ok := specRaw.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("spec is not a map")
	}

	return spec, nil
}

// extractServiceConfig extracts service configuration from Composition input
// Returns a map with: chart, defaultHelmValues, mapping, connectionSecret
func extractServiceConfig(input *structpb.Struct) (map[string]any, error) {
	inputMap := input.AsMap()
	paved := fieldpath.Pave(inputMap)

	dataRaw, err := paved.GetValue("data")
	if err != nil {
		return nil, fmt.Errorf("failed to get data from input: %w", err)
	}

	data, ok := dataRaw.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("data is not a map")
	}

	dataPaved := fieldpath.Pave(data)
	if _, err := dataPaved.GetValue("chart"); err != nil {
		return nil, fmt.Errorf("chart not found in service config")
	}
	if _, err := dataPaved.GetValue("defaultHelmValues"); err != nil {
		return nil, fmt.Errorf("defaultHelmValues not found in service config")
	}
	if _, err := dataPaved.GetValue("mapping"); err != nil {
		return nil, fmt.Errorf("mapping not found in service config")
	}
	// Note: connectionSecret is optional - not all services need it

	return data, nil
}

// mergeConfigs merges service config with user spec using the provided mapping
// Returns a merged config with: chart, helmValues (merged), connectionSecret
func mergeConfigs(serviceConfig map[string]any, userSpec map[string]any, log logr.Logger) (map[string]any, error) {
	servicePaved := fieldpath.Pave(serviceConfig)

	// Start with service's defaultHelmValues (deep copy)
	defaultHelmValuesRaw, err := servicePaved.GetValue("defaultHelmValues")
	if err != nil {
		return nil, fmt.Errorf("defaultHelmValues not found: %w", err)
	}
	defaultHelmValues, ok := defaultHelmValuesRaw.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("defaultHelmValues is not a map")
	}
	helmValues := deepCopy(defaultHelmValues)

	// Get mapping
	mappingRaw, err := servicePaved.GetValue("mapping")
	if err != nil {
		return nil, fmt.Errorf("mapping not found: %w", err)
	}
	mapping, ok := mappingRaw.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("mapping is not a map")
	}

	// Apply mappings: inject user spec values into helm values
	userSpecPaved := fieldpath.Pave(userSpec)
	helmValuesPaved := fieldpath.Pave(helmValues)

	for xrdPath, helmPathRaw := range mapping {
		helmPath, ok := helmPathRaw.(string)
		if !ok {
			log.Info("Skipping non-string helm path", "xrdPath", xrdPath, "helmPath", helmPathRaw)
			continue
		}

		// Get value from user spec using XRD path (remove "spec." prefix if present)
		actualPath := xrdPath
		if len(xrdPath) > 5 && xrdPath[:5] == "spec." {
			actualPath = xrdPath[5:]
		}

		value, err := userSpecPaved.GetValue(actualPath)
		if err != nil {
			// User didn't provide this field - skip it
			log.Info("User spec doesn't have value for path", "xrdPath", xrdPath)
			continue
		}

		// Set value in helm values using helm path
		if err := helmValuesPaved.SetValue(helmPath, value); err != nil {
			return nil, fmt.Errorf("failed to set helm value at %s: %w", helmPath, err)
		}
	}

	chartRaw, err := servicePaved.GetValue("chart")
	if err != nil {
		return nil, fmt.Errorf("chart not found: %w", err)
	}

	// Return merged config
	result := map[string]any{
		"chart":      chartRaw,
		"helmValues": helmValues,
	}

	// Include connectionSecret if present in service config
	if connectionSecret, err := servicePaved.GetValue("connectionSecret"); err == nil {
		result["connectionSecret"] = connectionSecret
	}

	return result, nil
}

// deepCopy creates a deep copy of a map[string]any
func deepCopy(src map[string]any) map[string]any {
	dst := make(map[string]any)
	for k, v := range src {
		switch val := v.(type) {
		case map[string]any:
			dst[k] = deepCopy(val)
		case []any:
			dst[k] = deepCopySlice(val)
		default:
			dst[k] = v
		}
	}
	return dst
}

// deepCopySlice creates a deep copy of a []any
func deepCopySlice(src []any) []any {
	dst := make([]any, len(src))
	for i, v := range src {
		switch val := v.(type) {
		case map[string]any:
			dst[i] = deepCopy(val)
		case []any:
			dst[i] = deepCopySlice(val)
		default:
			dst[i] = v
		}
	}
	return dst
}
