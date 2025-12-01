package v1alpha1

import (
	xpv1 "github.com/crossplane/crossplane-runtime/apis/common/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// RedisPocSpec defines the desired state of RedisPoc
type RedisPocSpec struct {
	xpv1.ResourceSpec `json:",inline"`
	// Parameters are the configurable fields of a RedisPoc
	Parameters RedisPocParameters `json:"parameters,omitempty"`
}

// RedisPocParameters are the configurable fields of a RedisPoc
type RedisPocParameters struct {
	// StorageSize defines the size of the Redis persistent volume (e.g., "16Gi")
	// +kubebuilder:default="16Gi"
	StorageSize string `json:"storageSize,omitempty"`
}

// RedisPocStatus defines the observed state of RedisPoc
type RedisPocStatus struct {
	xpv1.ResourceStatus `json:",inline"`
}

// +kubebuilder:object:root=true
// +kubebuilder:storageversion
// +kubebuilder:subresource:status
// +kubebuilder:resource:scope=Cluster,categories={crossplane,composite,poc}
// +kubebuilder:printcolumn:name="READY",type="string",JSONPath=".status.conditions[?(@.type=='Ready')].status"
// +kubebuilder:printcolumn:name="COMPOSITION",type="string",JSONPath=".spec.compositionRef.name"
// +kubebuilder:printcolumn:name="AGE",type="date",JSONPath=".metadata.creationTimestamp"

// RedisPoc is a minimal Redis composite resource for PoC
type RedisPoc struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   RedisPocSpec   `json:"spec"`
	Status RedisPocStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// RedisPocList contains a list of RedisPoc
type RedisPocList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []RedisPoc `json:"items"`
}

func init() {
	SchemeBuilder.Register(&RedisPoc{}, &RedisPocList{})
}