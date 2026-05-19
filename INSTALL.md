# Install FoodFinder + LoopInsights + AutoPresets

Add AI-powered food analysis, therapy settings insights, and automatic preset management to your Loop app — compatible with all Loop & Learn customizations.

## Quick Start

### 1. Build Loop the normal way first

Follow the standard LoopDocs build instructions through the cloning step:
https://loopkit.github.io/loopdocs/build/step4/

```bash
git clone --branch=main --recurse-submodules https://github.com/LoopKit/LoopWorkspace
cd LoopWorkspace
```

### 2. (Optional) Apply any Loop & Learn customizations you want

https://www.loopandlearn.org/custom-code/

All L&L patches (Profiles, Basal Lock, Negative Insulin, etc.) are compatible. Apply them first — our installer adapts to whatever's already there.

### 3. Run one command

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/TaylorJPatterson/LoopWorkspace/feat/installer/Scripts/install_features.sh)"
```

That's it. The script downloads everything it needs, installs 77 new files, patches 11 existing files, updates the Xcode project, and validates the result.

### 4. Build in Xcode

1. Open `LoopWorkspace.xcworkspace` in Xcode
2. Select your signing team
3. Build and run (Cmd+R)

### 5. Enable features in the app

All features are **off by default**. Turn them on in Loop Settings:

- **FoodFinder** — AI-powered & barcode food analysis
- **LoopInsights** — AI-powered therapy settings analysis
- **AutoPresets** — Automate presets during motion

You'll need an AI API key (OpenAI, Anthropic, or Google) for the AI features. Enter it in FoodFinder Settings — LoopInsights shares the same key.

---

## Uninstalling

```bash
./Scripts/install_features.sh --rollback
```

Removes all feature files and restores Loop to its pre-install state (including any L&L patches you had applied).

## Updating

```bash
./Scripts/install_features.sh --rollback
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/TaylorJPatterson/LoopWorkspace/feat/installer/Scripts/install_features.sh)"
```

## L&L Compatibility

| L&L Customization | Compatible | Notes |
|---|---|---|
| Profiles | Yes | Our features insert below Profiles in Settings |
| Basal Lock | Yes | Different code regions than our features |
| Negative Insulin | Yes | Different code regions than our features |
| Future Carbs 4h | Yes | Both modify CarbEntryView.swift in different regions; 3-way merge handles it |
| Override Insulin Needs Picker | Yes | No overlapping files |
| All other L&L patches | Yes | Our installer only modifies Loop submodule files |

## Troubleshooting

**"Anchor not found" error**: Your Loop version may be too old or too new. The installer targets Loop dev branch (v3.10.x+). Make sure you cloned the latest LoopWorkspace.

**Merge conflicts during patching**: If the installer reports conflicts, check the affected file for `<<<<<<<` conflict markers and resolve them manually.

**Xcode build errors after install**: Try a clean build (Cmd+Shift+K, then Cmd+R). If issues persist, run `--rollback` and re-install.

**plutil validation failure**: The Xcode project file update failed. The installer automatically restores the backup. Try again — if it persists, file an issue.
