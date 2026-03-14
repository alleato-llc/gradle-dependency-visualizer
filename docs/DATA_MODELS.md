# Data Models

All domain models live in `Packages/GradleDependencyVisualizerCore/Sources/.../Models/`. Models are simple value types (or value-like classes) with no business logic — computation belongs in calculators.

## Core Domain

### DependencyNode

The fundamental unit of the dependency graph. A recursive tree structure representing a single dependency.

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Auto-generated UUID-based identifier |
| `group` | `String` | Maven group (e.g., `com.google.guava`) |
| `artifact` | `String` | Maven artifact (e.g., `guava`) |
| `requestedVersion` | `String` | Version declared in build file |
| `resolvedVersion` | `String?` | Version Gradle resolved to (if different) |
| `isOmitted` | `Bool` | Omitted by Gradle (already satisfied elsewhere) |
| `isConstraint` | `Bool` | Constraint entry (not a real dependency) |
| `children` | `[DependencyNode]` | Direct transitive dependencies |

**Computed:**
- `coordinate` → `"group:artifact"`
- `hasConflict` → `resolvedVersion != nil && resolvedVersion != requestedVersion`
- `displayVersion` → `"1.0 -> 1.1"` or `"1.0"`
- `subtreeSize` → recursive count of all descendants + self

**Conformances:** `Sendable, Identifiable, Hashable, Codable` (final class)

**Special use:** Synthetic module nodes have `requestedVersion == "module"` — created by `MultiModuleTreeCalculator` to wrap per-module trees.

### DependencyTree

Root aggregate containing the full parsed dependency graph for one configuration.

| Property | Type | Description |
|----------|------|-------------|
| `projectName` | `String` | Gradle project name |
| `configuration` | `GradleConfiguration` | Build configuration used |
| `roots` | `[DependencyNode]` | Top-level dependencies |
| `conflicts` | `[DependencyConflict]` | All detected version conflicts |

**Computed:**
- `totalNodeCount` → sum of all root subtree sizes
- `maxDepth` → deepest path in the tree

**Conformances:** `Sendable, Equatable, Codable` (struct)

### DependencyConflict

A version conflict where Gradle resolved a different version than requested.

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | `"coordinate:requested:resolved:requestedBy"` |
| `coordinate` | `String` | `"group:artifact"` |
| `requestedVersion` | `String` | Version originally requested |
| `resolvedVersion` | `String` | Version Gradle chose |
| `requestedBy` | `String` | Coordinate of the requesting dependency |

**Conformances:** `Sendable, Identifiable, Hashable, Codable` (struct)

### GradleConfiguration

All supported Gradle dependency configurations.

| Case | Category | Description |
|------|----------|-------------|
| `compileClasspath` | Production | Compile-time dependencies |
| `runtimeClasspath` | Production | Runtime dependencies |
| `implementation` | Production | Implementation dependencies |
| `api` | Production | API dependencies (exposed to consumers) |
| `compileOnly` | Production | Compile-only (not in runtime) |
| `runtimeOnly` | Production | Runtime-only (not in compile) |
| `testCompileClasspath` | Test | Test compile-time |
| `testRuntimeClasspath` | Test | Test runtime |
| `testImplementation` | Test | Test implementation |
| `annotationProcessor` | Other | Annotation processors |
| `implementationDependenciesMetadata` | Other | Metadata configuration |

**Computed:** `displayName`, `description`

**Conformances:** `String, Sendable, CaseIterable, Codable` (enum)

### GradleModule

A subproject in a multi-module Gradle build.

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Same as `path` |
| `name` | `String` | Module display name (e.g., `app`) |
| `path` | `String` | Gradle path (e.g., `:app:feature`) |

**Conformances:** `Sendable, Identifiable, Equatable, Hashable, Codable` (struct)

---

## Analysis Results

### DependencyDiffResult

Result of comparing a baseline tree against a current tree.

| Property | Type | Description |
|----------|------|-------------|
| `baselineName` | `String` | Baseline project name |
| `currentName` | `String` | Current project name |
| `entries` | `[DependencyDiffEntry]` | All diff entries |

**Computed:** `added`, `removed`, `versionChanged`, `unchanged` — filtered views of `entries`

**Conformances:** `Sendable` (struct)

### DependencyDiffEntry

A single dependency's change status between baseline and current.

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | `"coordinate:changeKind"` |
| `coordinate` | `String` | `"group:artifact"` |
| `changeKind` | `ChangeKind` | `.added`, `.removed`, `.versionChanged`, `.unchanged` |
| `beforeVersion` | `String?` | Requested version in baseline |
| `afterVersion` | `String?` | Requested version in current |
| `beforeResolvedVersion` | `String?` | Resolved version in baseline |
| `afterResolvedVersion` | `String?` | Resolved version in current |

**Computed:** `effectiveBeforeVersion`, `effectiveAfterVersion` — prefers resolved over requested

**Conformances:** `Sendable, Identifiable, Hashable` (struct)

### FlatDependencyEntry

Flattened view of a dependency for the table view, aggregating all occurrences.

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | Same as `coordinate` |
| `group` | `String` | Maven group |
| `artifact` | `String` | Maven artifact |
| `coordinate` | `String` | `"group:artifact"` |
| `version` | `String` | Primary version |
| `hasConflict` | `Bool` | Any version conflict |
| `isOmitted` | `Bool` | Whether omitted |
| `occurrenceCount` | `Int` | Times this dependency appears |
| `usedBy` | `[String]` | Parent coordinates |
| `versions` | `Set<String>` | All version strings encountered |

**Conformances:** `Sendable, Identifiable, Hashable` (struct)

### ScopeValidationResult

A test library found in a production configuration.

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | `"coordinate:version:configuration"` |
| `coordinate` | `String` | `"group:artifact"` |
| `version` | `String` | Dependency version |
| `matchedLibrary` | `String` | Recognized library name (e.g., "JUnit 5") |
| `configuration` | `GradleConfiguration` | Configuration where found |
| `recommendation` | `String` | Suggested fix |

**Conformances:** `Sendable, Identifiable, Hashable` (struct)

### DuplicateDependencyResult

A dependency declared redundantly (cross-module or within-module).

| Property | Type | Description |
|----------|------|-------------|
| `id` | `String` | `"kind:coordinate"` |
| `coordinate` | `String` | `"group:artifact"` |
| `kind` | `DuplicateKind` | `.crossModule` or `.withinModule` |
| `modules` | `[String]` | Affected module names |
| `versions` | `[String: String]` | Module/config → version mapping |
| `hasVersionMismatch` | `Bool` | Whether versions differ across modules |
| `recommendation` | `String` | Suggested action |

**Conformances:** `Sendable, Identifiable, Hashable, Codable` (struct)

---

## Services Data Types

These types live in the Services package alongside their calculators/generators.

### NodePosition

Layout position for a single node, computed by `TreeLayoutCalculator`.

| Property | Type | Description |
|----------|------|-------------|
| `nodeId` | `String` | Corresponding `DependencyNode.id` |
| `x` | `Double` | Horizontal position |
| `y` | `Double` | Vertical position |
| `subtreeSize` | `Int` | For sizing calculations |

**Conformances:** `Sendable` (struct)

**Defined in:** `TreeLayoutCalculator.swift`

### GradleBuildFileParser.DependencyDeclaration

A dependency declaration parsed from a `build.gradle(.kts)` file.

| Property | Type | Description |
|----------|------|-------------|
| `configuration` | `String` | e.g., `implementation`, `testImplementation` |
| `group` | `String` | Maven group |
| `artifact` | `String` | Maven artifact |
| `version` | `String` | Declared version |
| `line` | `Int` | Line number in build file |

**Conformances:** `Sendable, Hashable` (struct)

**Defined in:** `GradleBuildFileParser.swift`

---

## Error Types

### GradleDependencyVisualizerError

App-level errors shown to the user via `ErrorPresenter`.

| Case | Description |
|------|-------------|
| `invalidProjectPath` | Selected path is not a valid directory |
| `gradlewNotFound` | No `gradlew` wrapper in project directory |
| `parsingFailed(String)` | Could not parse Gradle output |
| `executionFailed(String)` | Gradle command failed |

**Defined in:** `GradleDependencyVisualizer/Error.swift`

### GradleRunnerError

Errors from the Gradle subprocess execution.

| Case | Description |
|------|-------------|
| `gradlewNotFound(path:)` | `gradlew` not at expected path |
| `executionFailed(exitCode:stderr:)` | Non-zero exit code |
| `launchFailed(underlying:)` | Process launch failed |

**Defined in:** `ProcessGradleRunner.swift`

### TreeImportError

Errors from importing saved dependency trees.

| Case | Description |
|------|-------------|
| `unreadableFile` | File could not be read |
| `noDependenciesFound` | No dependencies parsed from file |

**Defined in:** `TreeImporter.swift`

---

## ID Generation Patterns

Each model generates its `id` from a composite key to ensure uniqueness within its context:

| Model | ID Formula |
|-------|------------|
| `DependencyNode` | `"group:artifact:requestedVersion:UUID"` |
| `DependencyConflict` | `"coordinate:requested:resolved:requestedBy"` |
| `DependencyDiffEntry` | `"coordinate:changeKind"` |
| `FlatDependencyEntry` | `coordinate` |
| `ScopeValidationResult` | `"coordinate:version:configuration"` |
| `DuplicateDependencyResult` | `"kind:coordinate"` |
| `GradleModule` | `path` |
