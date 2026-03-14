# Import / Export

## What

Import dependency trees from files and export data in multiple formats across all features.

## Import

### Supported formats

| Format | Extension | Auto-detected | Source |
|--------|-----------|---------------|--------|
| JSON tree | `.json` | Yes (tried first) | Exported by this app or hand-crafted |
| Gradle text output | `.txt`, other | Yes (fallback) | Saved output from `./gradlew dependencies` |

### How it works

`TreeImporter.importTree(from:fileName:fallbackConfiguration:)` auto-detects the format:
1. Tries `JsonTreeImporter` (JSON decoding)
2. Falls back to `TextGradleDependencyParser` (Gradle ASCII tree parsing)
3. Strips common filename suffixes (e.g., `-dependencies`, `-deps`) for the project name
4. Throws `TreeImportError.unreadableFile` or `.noDependenciesFound` on failure

### User flow

- **Import button** in the sidebar — opens `NSOpenPanel` for `.json` or `.txt` files
- **Compare baseline** — opens `NSOpenPanel` from the graph view toolbar to import a baseline for diffing

## Export

### Supported exports

| Feature | Format | Trigger | Implementation |
|---------|--------|---------|----------------|
| Dependency tree | JSON | "Export JSON" button | `JsonTreeExporter.export(tree:)` |
| Dependency graph | PNG | "Export PNG" button | `ImageRenderer` with memory-safe scale capping |
| Conflict report | JSON | Export in conflict table | `ConflictReportGenerator` |
| Conflict report | Text | CLI `conflicts` command | `ConflictReportGenerator` |
| Dependency table | JSON | Export in table view | Direct JSON encoding of flat entries |
| Dependency diff | JSON | Export in diff view | JSON encoding of filtered diff entries |
| Scope validation | JSON | Export in validation view | JSON encoding of validation results |
| DOT graph | Text | CLI `graph` command | `DotExportGenerator` |

### JSON tree format

Pretty-printed with sorted keys. Structure matches `DependencyTree` Codable conformance:

```json
{
  "configuration": "compileClasspath",
  "conflicts": [],
  "projectName": "my-project",
  "roots": [
    {
      "artifact": "spring-core",
      "children": [],
      "group": "org.springframework",
      "isConstraint": false,
      "isOmitted": false,
      "requestedVersion": "5.3.20"
    }
  ]
}
```

## Architecture

### Core types

- `TreeImporter` — auto-detecting import facade
- `JsonTreeImporter` — JSON deserialization via `JSONDecoder`
- `JsonTreeExporter` — JSON serialization with pretty printing and sorted keys
- `FileExporter` (protocol) — abstract file save interface; `PanelFileExporter` uses `NSSavePanel`

### File organization

```
Packages/GradleDependencyVisualizerServices/
  Sources/.../Export/
    TreeImporter.swift
    JsonTreeImporter.swift
    JsonTreeExporter.swift
    FileExporter.swift
    ConflictReportGenerator.swift
    DotExportGenerator.swift
    GradleTreeTextGenerator.swift
```

## Testing

- `TreeImporterTests` — JSON import, text import, format preference, config fallback, error cases, filename stripping
- `JsonTreeExporterTests` — valid UTF-8, pretty printing, sorted keys, field encoding, recursive children, empty tree
- `JsonTreeImporterTests` — error handling, minimal valid import, all fields, unique IDs, nested children, all configurations
- `JsonTreeRoundTripTests` — export then import preserves hierarchy, flags, conflicts
- `GradleTreeTextRoundTripTests` — export then import preserves structure for simple, deep, conflict, and omitted trees
