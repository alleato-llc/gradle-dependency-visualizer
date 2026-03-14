# Conflict Risk Assessment

## What

Assigns a risk level (CRITICAL, HIGH, MEDIUM, LOW, INFO) to each dependency conflict based on version distance, BOM management status, upgrade direction, and scope. Enables teams to prioritize which conflicts deserve attention rather than treating all conflicts equally.

## How

### User flow

1. User loads a dependency tree
2. If conflicts exist, the conflict table shows a "Risk" column with color-coded levels
3. Red = CRITICAL, Orange = HIGH, Yellow = MEDIUM, Green = LOW, Gray = INFO
4. Risk reason is available as a tooltip or in exported JSON

### Data flow

```
ConflictRiskCalculator.assessConflicts(tree:runner:projectPath:)
  → Step 1: collect unique conflict coordinates
  → Step 2: query dependencyInsight per coordinate (BOM detection)
  → Step 3: parse semver, compute base risk, apply adjustments
  → Step 4: return conflicts with riskLevel + riskReason populated

ConflictReportGenerator includes risk data in text/JSON output
ConflictTableView shows Risk column with color coding
```

### CLI usage

```bash
# Text report with risk levels
gradle-dependency-visualizer conflicts ./my-project --risk

# JSON report with risk fields
gradle-dependency-visualizer conflicts ./my-project --risk --format json
```

## Architecture

### Risk levels

| Level | Meaning |
|-------|---------|
| CRITICAL | Almost certainly breaks at runtime |
| HIGH | Likely to cause subtle issues |
| MEDIUM | Could break in edge cases |
| LOW | Theoretically possible but rare |
| INFO | Expected BOM behavior, safe to ignore |

### Step 1: Base risk from version distance

Versions are parsed as semver (major.minor.patch), stripping qualifiers like `.Final`, `.RELEASE`, `-jre`, `-SNAPSHOT`, `-beta1`. Multi-segment versions like `1.9.22.1` use the first three segments.

| Condition | Base Risk |
|-----------|-----------|
| Different major version (1.x → 2.x) | HIGH |
| Same major, different minor (2.15 → 2.19) | MEDIUM |
| Same major+minor, different patch (6.2.15 → 6.2.16) | LOW |
| Only qualifier differs | INFO |

Unparseable versions default to MEDIUM.

### Step 2: Contextual adjustments

Each adjustment shifts the risk by one level, clamped to INFO..CRITICAL.

**BOM-managed (−1 level):** Queries `gradle dependencyInsight --dependency <coordinate> --configuration <config> -q` via the `GradleRunner` protocol and parses the first line. If the selection reason is `(selected by rule)` or `(by constraint)`, the dependency is BOM-managed. Falls back to checking constraint nodes in the tree if the runner call fails.

**Downgrade (+1 level):** If the resolved version is lower than the requested version (semver comparison), the risk increases.

**Test scope (−1 level):** If the tree's configuration is a test configuration, the risk decreases.

### Combined formula

```
risk = base_risk(requested, resolved)
if bom_managed:     risk -= 1
if downgrade:       risk += 1
if test_scope:      risk -= 1
risk = clamp(risk, INFO, CRITICAL)
```

### BOM detection via dependencyInsight

The `dependencyInsight` Gradle task reveals *why* a particular version was selected — information not available from `gradle dependencies` text output:

- `(selected by rule)` → BOM-managed (Spring dependency-management plugin)
- `(by constraint)` → BOM-managed (Gradle platform/BOM)
- No selection reason → default conflict resolution, not BOM-managed

### Design decisions

- **RiskLevel** lives in Core package — used by models, services, and views
- **ConflictRiskCalculator** is async — `dependencyInsight` queries require Gradle execution
- **GradleRunner protocol** extended with default empty implementation — existing conformances aren't broken
- **Risk fields are optional** on `DependencyConflict` — nil when not assessed, omitted from JSON via `encodeIfPresent`
- **Tree-based fallback** — if `dependencyInsight` fails (no gradlew, offline), falls back to checking constraint `(c)` nodes in the tree

### File organization

```
Packages/GradleDependencyVisualizerCore/
  Sources/.../Models/RiskLevel.swift
  Sources/.../Models/DependencyConflict.swift          (riskLevel, riskReason fields)
  Sources/.../Models/GradleConfiguration.swift         (isProduction computed property)
Packages/GradleDependencyVisualizerServices/
  Sources/.../Analysis/ConflictRiskCalculator.swift
  Sources/.../Execution/GradleRunner.swift             (runDependencyInsight method)
  Sources/.../Execution/ProcessGradleRunner.swift      (dependencyInsight subprocess)
  Sources/.../Export/ConflictReportGenerator.swift      (risk in text/JSON output)
GradleDependencyVisualizer/
  ViewModels/ConflictTableViewModel.swift              (riskLevel sort field)
  Views/Conflict/ConflictTableView.swift               (Risk column with color coding)
```

## Testing

- `ConflictRiskCalculatorTests` — 13 tests: major/minor/patch/qualifier classification, BOM reduction via insight, BOM reduction via constraint output, BOM fallback to tree heuristic, downgrade escalation, test scope reduction, combined adjustments, non-semver fallback, multi-segment versions, real Spring Boot scenario
