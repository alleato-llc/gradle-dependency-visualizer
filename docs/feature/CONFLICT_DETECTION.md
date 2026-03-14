# Conflict Detection

## What

Detects and reports Gradle dependency version conflicts — where a transitive dependency requests one version but Gradle resolves a different version. Conflicts appear as red nodes in the graph and as a sortable table.

## How

### User flow

1. After loading dependencies, conflict nodes appear in red in the graph
2. If conflicts exist, a "View Conflicts" toolbar button appears
3. Clicking it reveals a sortable table below the graph showing:
   - Dependency coordinate (group:artifact)
   - Requested version
   - Resolved version (in red)
   - Requested by (parent dependency)
   - Risk level (color-coded: red=CRITICAL, orange=HIGH, yellow=MEDIUM, green=LOW, gray=INFO)
4. Table columns are sortable by clicking headers

### Data flow

```
TextGradleDependencyParser.parse()
  → detects " -> " in dependency line
  → creates DependencyNode with resolvedVersion set
  → creates DependencyConflict record with parent tracking
  → DependencyTree.conflicts populated

ContentView.onChange(of: dependencyTree)
  → ConflictTableViewModel(tree:)
  → ConflictTableView renders sortable Table
```

## Architecture

### Design decisions

- **Inline conflict detection** during parsing — conflicts are detected as the ASCII tree is parsed, not in a separate pass. The parser tracks the parent node via the stack to populate `requestedBy`.
- **Dual representation** — conflicts exist both as `DependencyNode.hasConflict` (for graph coloring) and `DependencyConflict` records (for the table). This avoids re-walking the tree.
- **Sortable Table** — macOS native `Table` with four columns, togglable sort direction per column.

### Core models

- `DependencyConflict` — `coordinate`, `requestedVersion`, `resolvedVersion`, `requestedBy`, optional `riskLevel` and `riskReason`
- `RiskLevel` — `.info`, `.low`, `.medium`, `.high`, `.critical`
- `DependencyNode.hasConflict` — computed: `resolvedVersion != nil && resolvedVersion != requestedVersion`
- `DependencyNode.displayVersion` — shows `"requested -> resolved"` when conflict exists

### Core types

- `ConflictTableViewModel` — owns conflict list, sort field (including `.riskLevel`), sort direction
- `ConflictTableView` — macOS `Table` with 5 columns (including Risk with color coding)
- `ConflictRiskCalculator` — computes risk levels via semver distance + `dependencyInsight` BOM detection
- `ConflictReportGenerator` — text and JSON report generation (includes risk data when present)
- `DependencyAnalysisCalculator.conflictsByCoordinate()` — groups conflicts for analysis

### File organization

```
Packages/GradleDependencyVisualizerCore/
  Sources/.../Models/RiskLevel.swift
  Sources/.../Models/DependencyConflict.swift
Packages/GradleDependencyVisualizerServices/
  Sources/.../Analysis/ConflictRiskCalculator.swift
  Sources/.../Analysis/DependencyAnalysisCalculator.swift
  Sources/.../Export/ConflictReportGenerator.swift
GradleDependencyVisualizer/
  ViewModels/ConflictTableViewModel.swift
  Views/Conflict/ConflictTableView.swift
```

## CLI Support

```bash
# Text report
./gradle-dependency-visualizer conflicts /path/to/project

# JSON report
./gradle-dependency-visualizer conflicts /path/to/project --format json

# With risk assessment (runs dependencyInsight per conflict)
./gradle-dependency-visualizer conflicts /path/to/project --risk
./gradle-dependency-visualizer conflicts /path/to/project --risk --format json
```

See [Risk Assessment](RISK_ASSESSMENT.md) for details on risk levels and BOM detection.

## Testing

- `ConflictReportGeneratorTests` — text/JSON output, empty/populated conflicts
- `ConflictTableViewModelTests` — conflict loading, sort field toggling, ascending/descending
- `DependencyAnalysisCalculatorTests` — conflict grouping by coordinate
- `TextGradleDependencyParserTests` — conflict marker parsing, parent tracking
- `ConflictRiskCalculatorTests` — risk levels, BOM detection, downgrades, combined adjustments

## Limitations

- Conflict `requestedBy` only tracks the immediate parent, not the full dependency chain
- No conflict resolution suggestions (Gradle decides the resolved version)
- Conflict table does not link back to graph node selection
