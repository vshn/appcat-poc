#!/usr/bin/env bash
# Package Crossplane xpkg as OCI image
# Usage: package-xpkg.sh <input-dir> <output-file>

set -euo pipefail

INPUT_DIR="${1:?Input directory required}"
OUTPUT_FILE="${2:?Output file required}"

if [[ ! -d "$INPUT_DIR" ]]; then
    echo "Error: Input directory not found: $INPUT_DIR" >&2
    exit 1
fi

# Check for required tools
if ! command -v crossplane &> /dev/null; then
    echo "Error: crossplane CLI not found" >&2
    echo "Install from: https://docs.crossplane.io/latest/cli/" >&2
    exit 1
fi

# Create temporary directory for packaging
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "Packaging xpkg from $INPUT_DIR..."

# Copy all YAML files to temp directory
cp "$INPUT_DIR"/*.yaml "$TEMP_DIR/" 2>/dev/null || true

# Check if crossplane.yaml exists, if not create a basic one
if [[ ! -f "$TEMP_DIR/crossplane.yaml" ]]; then
    echo "Warning: crossplane.yaml not found, creating basic metadata..." >&2

    # Extract service name from directory path
    service_name=$(basename "$(dirname "$INPUT_DIR")")

    cat > "$TEMP_DIR/crossplane.yaml" <<EOF
apiVersion: meta.pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: appcat-$service_name
  annotations:
    meta.crossplane.io/maintainer: VSHN AG
    meta.crossplane.io/source: github.com/vshn/appcat
    meta.crossplane.io/description: AppCat $service_name service configuration
spec:
  crossplane:
    version: ">=v1.15.0"
  dependsOn:
    - provider: xpkg.upbound.io/crossplane-contrib/provider-kubernetes
      version: ">=v0.12.1"
    - provider: xpkg.upbound.io/crossplane-contrib/provider-helm
      version: ">=v0.17.0"
    - function: xpkg.upbound.io/vshn/function-appcat
      version: ">=v0.6.0"
EOF
fi

# Build the package using crossplane CLI
echo "Building package with crossplane CLI..."
mkdir -p "$(dirname "$OUTPUT_FILE")"

crossplane xpkg build \
    --package-root="$TEMP_DIR" \
    --package-file="$OUTPUT_FILE" \
    --verbose

echo "Package built successfully: $OUTPUT_FILE"
ls -lh "$OUTPUT_FILE"

# Optionally push to registry if XPKG_REGISTRY is set
if [[ -n "${XPKG_REGISTRY:-}" ]]; then
    service_name=$(basename "$(dirname "$INPUT_DIR")")
    registry_url="${XPKG_REGISTRY}/appcat-${service_name}:${XPKG_VERSION:-latest}"

    echo "Pushing to registry: $registry_url"
    crossplane xpkg push \
        --package-files="$OUTPUT_FILE" \
        "$registry_url"

    echo "Package pushed successfully"
fi
