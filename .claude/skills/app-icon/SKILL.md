---
name: app-icon
version: 1.0.0
category: Build
description: Programmatic app icon generation via Python/Pillow, integrated into XcodeGen build
---

# App Icon

## Pattern

Describe app icons in code, not image editors. A Python/Pillow script is the single source of truth for the icon — the generated PNG is a derived artifact.

## Generation

`scripts/generate_icon.py` produces a 1024x1024 PNG at `GradleDependencyVisualizer/Assets.xcassets/AppIcon.appiconset/icon.png`.

```bash
python3 scripts/generate_icon.py              # Generate to default path
python3 scripts/generate_icon.py output.png   # Generate to custom path
```

The script is idempotent — safe to run repeatedly.

## Integration

XcodeGen's `preBuildScripts` in `project.yml` runs the script automatically before each build. If `python3` is not available, the build continues with a warning.

```yaml
preBuildScripts:
  - name: Generate App Icon
    script: |
      VENV_DIR="${PROJECT_DIR}/scripts/.venv"
      VENV_PYTHON="${VENV_DIR}/bin/python3"
      if [ -x "$VENV_PYTHON" ]; then
        "$VENV_PYTHON" "${PROJECT_DIR}/scripts/generate_icon.py"
      elif command -v python3 &>/dev/null; then
        python3 "${PROJECT_DIR}/scripts/generate_icon.py"
      else
        echo "warning: python3 not found, skipping icon generation"
      fi
    basedOnDependencyAnalysis: false
```

Required build settings in `project.yml`:
```yaml
settings:
  base:
    ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    INFOPLIST_KEY_CFBundleIconName: AppIcon
```

## Maintenance

To change the icon, edit `scripts/generate_icon.py` — modify colors, shapes, or composition. The PNG is regenerated on the next build. Never edit the PNG directly.

## Dependencies

- Python 3
- Pillow (`pip install -r scripts/requirements.txt`)

## Rules

1. The generated PNG is gitignored — never commit it
2. `scripts/generate_icon.py` is the source of truth for the icon
3. The script must be idempotent and produce a 1024x1024 PNG
4. `Contents.json` references `icon.png` with `"filename": "icon.png"`
5. `Assets.xcassets/Contents.json` must exist (root asset catalog metadata)
6. Both `ASSETCATALOG_COMPILER_APPICON_NAME` and `INFOPLIST_KEY_CFBundleIconName` must be set to `AppIcon`
