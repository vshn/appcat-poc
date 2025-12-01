# PoC XFN2 Implementation Progress

## Phase 1: Add Minimal Resources to PoC

### ✅ Completed (62.5%)

#### Step 1.0: Create Minimal XRD for PoC ✅
- Created `apis/v1alpha1/doc.go`
- Created `apis/v1alpha1/groupversion_info.go`
- Created `apis/v1alpha1/redis_types.go`
- Generated `apis/v1alpha1/zz_generated.deepcopy.go`
- Generated `config/xrd/poc.appcat.vshn.io_redispocs.yaml`
- API: `poc.appcat.vshn.io/v1alpha1` - `RedisPoc`
- Plural: `redispocs`
- Parameter: `storageSize` (default: "16Gi")

#### Step 1.1: Namespace Builder ✅
- `NewNamespaceBuilder(name)` - fluent API
- Methods: `WithLabel()`, `WithLabels()`, `WithAnnotation()`, `Build()`
- Returns: `*corev1.Namespace`
- **Used in redis_poc.go** to create target namespace with Crossplane labels

#### Step 1.2: Secret Builder ✅
- `NewSecretBuilder(name, namespace)` - fluent API
- Methods: `WithData()`, `WithStringData()`, `WithLabel()`, `WithLabels()`, `WithRandomPassword()`, `Build()`
- Returns: `*corev1.Secret`

#### Step 1.2+: HelmRelease Builder ✅ (Upgraded!)
- `NewHelmReleaseBuilder(name)` - fluent API (cluster-scoped, no namespace param)
- Uses typed `*helmv1.Release` instead of unstructured
- Methods: `WithChart()`, `WithTargetNamespace()`, `WithValues()`, `WithValue()`, `WithLabel()`, `Build()`
- Returns: `*helmv1.Release`
- **Used in redis_poc.go** to deploy Helm chart into target namespace

#### Step 1.4a: Integrate Namespace into Redis PoC ✅
- Updated `redisState` struct to include Namespace
- Updated `SetObserved()` to observe namespace resource
- Create Namespace with labels: `app.kubernetes.io/managed-by=crossplane`, `app.kubernetes.io/part-of=redis-poc`
- HelmRelease deploys into created namespace
- Build passes ✅

#### Step 1.5: BaseState Implementation & Flow Fixes ✅
**Implemented generic BaseState to eliminate boilerplate:**
1. ✅ Added `observedResources` to `ServiceRuntime` - loaded in `NewServiceRuntime()` (runtime.go:64,77-80)
2. ✅ Updated `ObserveState()` to use pre-loaded observed resources (runtime.go:235-238)
3. ✅ Created `ResourceDescriptor` type with Name, Optional, Type fields (runtime.go:149-153)
4. ✅ Created generic `BaseState[T]` with automatic `Desired()` and `SetObserved()` (runtime.go:156-215)
   - Uses reflection to convert struct fields to/from DesiredResource array
   - Supports typed conversion (Type != nil) or Unstructured (Type == nil)
   - Zero boilerplate for services!
5. ✅ Updated redis_poc.go to use BaseState (redis_poc.go:43)
   - Type alias: `type redisState = BaseState[redisResources]`
   - Descriptors: namespace, redis-secret (optional), helmrelease
   - **Eliminated 40 lines** of manual Desired() and SetObserved() code
6. ✅ **Fixed execution flow** (redis_poc.go:19-28):
   - Before: buildState() → Apply() → Observe() ❌ (backwards!)
   - After: newState() → Observe() → buildDesired() → Apply() ✅ (correct!)
7. ✅ Build passes with zero boilerplate

**Architecture improvements:**
- Observed resources loaded ONCE in NewServiceRuntime (efficient)
- ObserveState() just populates state struct (no fetching)
- Services define descriptors → get Desired()/SetObserved() for free
- buildDesired() has access to observed data (for connection details, conditional logic)
- Correct flow: observe first, then build desired based on observed

**Benefits for adding new services:**
```go
// Define resources
type myResources struct {
    Foo *corev1.ConfigMap
    Bar client.Object
}

// Use BaseState - that's it!
type myState = BaseState[myResources]

func newMyState() *myState {
    return NewBaseState[myResources]([]ResourceDescriptor{
        {Name: "foo", Type: reflect.TypeOf(&corev1.ConfigMap{})},
        {Name: "bar", Type: nil},
    })
}
// Desired() and SetObserved() provided automatically!
```

#### Step 1.3: Runtime Connection Details ✅ COMPLETE
- ✅ Added `connectionDetails map[string][]byte` to ServiceRuntime (runtime.go:70)
- ✅ Added `SetConnectionDetail()` and `SetConnectionDetailString()` helper methods (runtime.go:268-274)
- ✅ Updated `GetResponse()` to export connection details on composite resource (runtime.go:131-140)

#### Step 1.4b: Secret & Connection Details in Redis PoC ✅ COMPLETE
- ✅ Added Secret to `redisResources` struct (redis_poc.go:40)
- ✅ Secret with password generation/reuse logic (redis_poc.go:77-97)
  - Reuses password from observed secret if exists
  - Generates new random 16-char password on first run
- ✅ HelmRelease references secret via `existingSecret` (redis_poc.go:101-104)
- ✅ Implemented `setRedisConnectionDetails()` function (redis_poc.go:120-136)
- ✅ Exports 5 connection details: REDIS_HOST, REDIS_PORT, REDIS_USERNAME, REDIS_PASSWORD, REDIS_URL
- ✅ Build passes with 3 resources (Namespace, Secret, HelmRelease)

### 🎯 Phase 1 Complete: 100% (8 of 8 steps)

**Summary of Achievements:**
1. ✅ Minimal XRD created (RedisPoc API)
2. ✅ Three builders implemented (Namespace, Secret, HelmRelease)
3. ✅ BaseState generic pattern eliminates boilerplate
4. ✅ Redis PoC with 3 resources
5. ✅ Password persistence (reuse on updates)
6. ✅ Connection details export
7. ✅ Correct execution flow (Observe → Build → Apply → Export)
8. ✅ Zero boilerplate state management

## Phase 2: Configuration Architecture (PLANNING)

### Next Priority: KCL Template Integration

**Goal**: Define resource structure in KCL ConfigMap, not Go code

**Approach**: Hybrid model (PoC coexistence)
- Keep builders for now (proven, type-safe)
- Add template rendering capability
- KCL provides templates with `__PLACEHOLDERS__`
- Go renders templates and passes to builders
- Later: decide between full templating vs hybrid

**Key Decisions Made:**
1. Use `__PLACEHOLDER__` syntax (easy to spot, no escaping issues)
2. Generic `RenderTemplate()` helper function
3. Start with `helmValuesTemplate` (Phase 2.1)
4. Eventually all resources as templates (Phase 2.2)
5. Builders coexist with templates during PoC

### ⏳ Remaining Tasks

#### Step 2.1: Add RenderTemplate() Helper ✅
- ✅ Added generic `RenderTemplate(template string, ctx map[string]string)` to runtime.go:276-282
- ✅ Simple string replacement using `strings.ReplaceAll()`
- ✅ Documented with usage example
- ✅ Build passes

#### Step 2.2: Fix Runtime Name Derivation ✅ CRITICAL
**Issue**: Hardcoded names break multi-instance deployments

**Fixed in redis_poc.go**:
- ✅ Line 69: `compositeName := svc.desiredComposite.GetName()` - get instance name from composite
- ✅ Line 70: `targetNamespace := fmt.Sprintf("vshn-redis-%s", compositeName)` - dynamic namespace (e.g., "vshn-redis-my-instance")
- ✅ Line 71: `secretName := fmt.Sprintf("%s-helm-secret", compositeName)` - dynamic secret name (e.g., "my-instance-helm-secret")
- ✅ Line 130-131: Updated `setRedisConnectionDetails()` to also derive namespace dynamically
- ✅ Build passes - multi-instance deployments now supported!

#### Step 2.3: Add helmValuesTemplate to KCL ConfigMap ⏳ BLOCKED
**Status**: Waiting for proper KCL documentation structure
- Need to document KCL structure in ../../kcl/ folder first
- Template format will be:
```yaml
data:
  serviceName: redis-poc
  chartRepository: https://charts.bitnami.com/bitnami
  chartVersion: "18.0.0"
  helmValuesTemplate: |
    {
      "auth": {
        "enabled": true,
        "existingSecret": "__SECRET_NAME__"
      },
      "networkPolicy": {"enabled": true}
    }
```

#### Step 2.4: Update buildRedisDesired() to Use Templates ✅ (Ready for KCL)
**Implemented in redis_poc.go:102-131**:
- ✅ Checks for `helmValuesTemplate` in config (line 105)
- ✅ If present: Renders template with RenderTemplate() and runtime values (lines 107-115)
- ✅ If absent: Falls back to hardcoded values for backward compatibility (lines 117-125)
- ✅ Hybrid approach: Template coexists with builders during PoC
- ✅ Placeholders supported: `__SECRET_NAME__`, `__NAMESPACE__`
- ✅ Error handling: Fatal result if JSON parsing fails
- ✅ Build passes

**When KCL adds helmValuesTemplate, code will automatically use it!**

## Files Created/Modified

### Created ✅
- `apis/v1alpha1/doc.go`
- `apis/v1alpha1/groupversion_info.go`
- `apis/v1alpha1/redis_types.go`
- `apis/v1alpha1/zz_generated.deepcopy.go` (auto-generated)
- `config/xrd/poc.appcat.vshn.io_compositeredispocs.yaml` (auto-generated)

### Modified ✅
- `builders.go` - Added NamespaceBuilder, SecretBuilder, HelmReleaseBuilder
- `runtime.go` - Added BaseState[T], connection details support, RenderTemplate() helper
- `redis_poc.go` - Uses all builders, creates 3 resources, exports connection details, template rendering support
- `go.mod` - Added provider-helm dependency

## Phase 1: 100% Complete! 🎉

## Phase 2: Template Configuration (75% Complete)

### Completed ✅
1. ✅ **RenderTemplate() Helper** (Step 2.1) - Generic template rendering with __PLACEHOLDER__ syntax
2. ✅ **Runtime Name Derivation** (Step 2.2) - Dynamic namespace and secret names from composite
3. ✅ **Template Rendering in buildRedisDesired()** (Step 2.4) - Ready to consume helmValuesTemplate from KCL

### Remaining ⏳
1. ⏳ **helmValuesTemplate in KCL** (Step 2.3) - BLOCKED: Need KCL documentation structure first

### Key Achievements
- **Hybrid architecture working**: Templates coexist with builders
- **Multi-instance support**: Each composite gets unique namespace/secrets
- **Template-ready code**: Will auto-detect and use helmValuesTemplate when added to KCL
- **Backward compatible**: Falls back to hardcoded values if template not present

## Phase 3: Build Infrastructure ✅ COMPLETE

### Goal
Create self-contained build system for packaging and distributing the Crossplane function.

### Completed Tasks
1. ✅ **Created Dockerfile** - Alpine 3.15-based runtime image with non-root user (65532)
2. ✅ **Created package/crossplane.yaml** - Function metadata requiring Crossplane 2.0+
3. ✅ **Created Makefile** - Self-contained build orchestration (no parent dependencies)
4. ✅ **Created .gitignore** - Excludes binary and XPKG artifacts

### Target Artifacts
- **Runtime Image**: `ghcr.io/vshn/function-appcat-poc:latest`
- **XPKG Package**: `ghcr.io/vshn/function-appcat-poc:latest-func`

### Available Make Targets
- `make build` - Build Go binary (Linux AMD64) → 55MB binary ✅
- `make docker-build` - Build Docker image ✅ Tested
- `make package-build` - Build XPKG with embedded runtime image
- `make package-push` - Push XPKG to ghcr.io
- `make release` - Build and push both Docker image and XPKG
- `make *-local` - Local development targets (localhost:5000)
- `make *-branchtag` - CI/CD targets with branch name as tag
- `make help` - Display all available targets with descriptions ✅
- `make clean` - Remove build artifacts ✅

### Files Created
- `Dockerfile` - Alpine-based container with function-appcat-poc binary
- `package/crossplane.yaml` - Crossplane Function metadata (v2.0+)
- `Makefile` - 103 lines, self-contained build system
- `.gitignore` - Build artifacts exclusion

### Verification
- ✅ `make build` creates `function-appcat-poc` binary (55MB)
- ✅ `make help` displays all targets with nice formatting
- ✅ `make docker-build` successfully builds Alpine image
- ✅ `make clean` removes artifacts