#!/usr/bin/env bash
# install_features.sh — Loop (AID) PowerPack installer
#
# FULL FLOW
#   Loop core + (optional) L&L customizations + PowerPack features + build.
#   Run with no args, anywhere, and the installer walks you through it.
#
# USAGE
#   ./Scripts/install_features.sh                     interactive (default)
#   ./Scripts/install_features.sh --all               install every PowerPack feature non-interactively
#   ./Scripts/install_features.sh --rollback          uninstall every installed PowerPack feature
#   ./Scripts/install_features.sh --feature <id>      install one feature non-interactively
#   ./Scripts/install_features.sh --uninstall <id>    uninstall one feature non-interactively
#
# FEATURE IDS
#   site_atlas, ai_suite
#
#   `ai_suite` bundles AutoPresets + BolusPro + FoodFinder + LoopInsights
#   + DataLayer + GraphDetailView (they share compile-time symbols and
#   install together). Only SiteAtlas is genuinely standalone.
#
# ONE-LINER (anywhere — installer detects whether you're in a LoopWorkspace):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/LoopPowerPack/LoopWorkspace/feat/installer/Scripts/install_features.sh)"
#
# Idea by Taylor Patterson. Coded by Claude Code.
# Copyright © 2026 LoopKit Authors and Taylor Patterson.

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# 1. CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || pwd)"
FEATURE_REMOTE="_powerpack_src"
FEATURE_REPO="https://github.com/LoopPowerPack/Loop.git"
FEATURE_INTEGRATION_BRANCH="feat/AllFeatures"
FEATURE_DEV_BRANCH="dev"
WORKSPACE_REPO="https://raw.githubusercontent.com/LoopPowerPack/LoopWorkspace/feat/installer"
OMNIBLE_POD_KEEP_ALIVE_SHA="dade6ed309eb72232a187d88179a367e34f800d9"
FEATURE_VERSION="3.13.1"
FEATURE_BUILD="58"
LEGACY_MARKER=".feature_install_marker"

# ─────────────────────────────────────────────────────────────────────────────
# 2. COLOR + LOG HELPERS
# ─────────────────────────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; NC=''
fi

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*" >&2; }
header()  { echo -e "\n${BOLD}═══ $* ═══${NC}"; }
die()     { error "$@"; exit 1; }

# ─────────────────────────────────────────────────────────────────────────────
# 3. FEATURE REGISTRY
# ─────────────────────────────────────────────────────────────────────────────

# Feature ids in display order. Easy four first, then the heavy two.
ALL_FEATURE_IDS=(autopresets bolus_pro graph_detail_view site_atlas food_finder loop_insights)

# Feature display name + description lookups.
# Written as case-statement functions because macOS ships bash 3.2 (no
# associative-array support); `declare -A` would silently fail and trigger
# "unbound variable" under `set -u` when looking up `${FOO[bar]}`.
feature_name() {
    case "$1" in
        autopresets)        echo "AutoPresets" ;;
        bolus_pro)          echo "BolusPro" ;;
        graph_detail_view)  echo "GraphDetailView" ;;
        site_atlas)         echo "SiteAtlas" ;;
        food_finder)        echo "FoodFinder" ;;
        loop_insights)      echo "LoopInsights" ;;
        *)                  echo "$1" ;;
    esac
}
feature_desc() {
    case "$1" in
        autopresets)        echo "Auto-activate Loop overrides on detected motion" ;;
        bolus_pro)          echo "Protein/fat-aware bolusing for high-FPU meals" ;;
        graph_detail_view)  echo "Long-press chart for detailed timestamp data" ;;
        site_atlas)         echo "Body-map tracker for pump/CGM site rotation" ;;
        food_finder)        echo "AI-assisted carb counting from photos/barcodes" ;;
        loop_insights)      echo "AI therapy tuning, Behavior Insights, DataLayer" ;;
        *)                  echo "" ;;
    esac
}

marker_path_for() { echo "Loop/.feature_installed_$1"; }
is_installed()    { [[ -f "$(marker_path_for "$1")" ]]; }
write_marker()    {
    local p; p="$(marker_path_for "$1")"
    mkdir -p "$(dirname "$p")"
    echo "feature=$1" > "$p"
    echo "installed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$p"
}
remove_marker()   { rm -f "$(marker_path_for "$1")"; }

# ─────────────────────────────────────────────────────────────────────────────
# 4. PER-FEATURE FILE MANIFESTS
# Source: feat/AllFeatures branch on LoopPowerPack/Loop.
# Paths are relative to the Loop submodule root (i.e. inside LoopWorkspace/Loop/).
# ─────────────────────────────────────────────────────────────────────────────

files_for_autopresets() { cat <<'EOF'
Documentation/AutoPresets/AutoPresets_README.md
Documentation/AutoPresets/AutoPresets_DEVELOPER.md
Loop/Managers/AutoPresets/AutoPresets_ActivityDetectionManager.swift
Loop/Managers/AutoPresets/AutoPresets_CalendarManager.swift
Loop/Managers/AutoPresets/AutoPresets_Coordinator.swift
Loop/Managers/AutoPresets/AutoPresets_Delegate.swift
Loop/Managers/AutoPresets/AutoPresets_GeofenceManager.swift
Loop/Managers/AutoPresets/AutoPresets_Logger.swift
Loop/Managers/AutoPresets/AutoPresets_Storage.swift
Loop/Models/AutoPresets/AutoPresets_Models.swift
Loop/Models/AutoPresets/AutoPresets_RecommendationModels.swift
Loop/Resources/AutoPresets/AutoPresets_FeatureFlags.swift
Loop/Services/AutoPresets/AutoPresets_AIAdvisor.swift
Loop/Views/AutoPresets/AutoPresets_AIRecommendationView.swift
Loop/Views/AutoPresets/AutoPresets_CalendarSettingsView.swift
Loop/Views/AutoPresets/AutoPresets_GeofenceSettingsView.swift
Loop/Views/AutoPresets/AutoPresets_SettingsView.swift
EOF
}

files_for_bolus_pro() { cat <<'EOF'
Documentation/BolusPro/BolusPro_README.md
Documentation/BolusPro/BolusPro_DEVELOPER.md
Loop/Models/BolusPro/BolusPro_Models.swift
Loop/Resources/BolusPro/BolusPro_FeatureFlags.swift
Loop/Services/BolusPro/BolusPro_BehaviorAnalyzer.swift
Loop/Services/BolusPro/BolusPro_DataLayerHook.swift
Loop/Services/BolusPro/BolusPro_FPUCalculator.swift
Loop/Views/BolusPro/BolusPro_CarbEntrySection.swift
Loop/Views/BolusPro/BolusPro_InfoSheet.swift
Loop/Views/BolusPro/BolusPro_ManualMacroFields.swift
Loop/Views/BolusPro/BolusPro_OnboardingView.swift
Loop/Views/BolusPro/BolusPro_SettingsView.swift
EOF
}

files_for_graph_detail_view() { cat <<'EOF'
Documentation/GraphDetailView/GraphDetailView_README.md
Documentation/GraphDetailView/GraphDetailView_DEVELOPER.md
Loop/Managers/GraphDetailViewModel.swift
Loop/Views/GraphDetailView.swift
EOF
}

files_for_site_atlas() { cat <<'EOF'
Documentation/SiteAtlas/SiteAtlas_README.md
Documentation/SiteAtlas/SiteAtlas_DEVELOPER.md
Loop/Models/SiteAtlas/SiteAtlas_Models.swift
Loop/Services/SiteAtlas/SiteAtlas_Coordinator.swift
Loop/Services/SiteAtlas/SiteAtlas_FeatureFlags.swift
Loop/Services/SiteAtlas/SiteAtlas_Storage.swift
Loop/Views/SiteAtlas/SiteAtlas_BodyMapView.swift
Loop/Views/SiteAtlas/SiteAtlas_SettingsView.swift
Loop/Views/SiteAtlas/SiteAtlas_SiteSelectionSheet.swift
EOF
}

files_for_food_finder() { cat <<'EOF'
Documentation/FoodFinder/FoodFinder_README.md
Documentation/FoodFinder/FoodFinder_DEVELOPER.md
Loop/Models/FoodFinder/FoodFinder_AnalysisRecord.swift
Loop/Models/FoodFinder/FoodFinder_InputResults.swift
Loop/Models/FoodFinder/FoodFinder_Models.swift
Loop/Resources/FoodFinder/FoodFinder_FeatureFlags.swift
Loop/Services/FoodFinder/FoodFinder_AIAnalysis.swift
Loop/Services/FoodFinder/FoodFinder_AIProviderConfig.swift
Loop/Services/FoodFinder/FoodFinder_AIServiceAdapter.swift
Loop/Services/FoodFinder/FoodFinder_AIServiceManager.swift
Loop/Services/FoodFinder/FoodFinder_AnalysisHistoryStore.swift
Loop/Services/FoodFinder/FoodFinder_CarbTrackingService.swift
Loop/Services/FoodFinder/FoodFinder_EmojiProvider.swift
Loop/Services/FoodFinder/FoodFinder_ImageDownloader.swift
Loop/Services/FoodFinder/FoodFinder_ImageStore.swift
Loop/Services/FoodFinder/FoodFinder_LocationService.swift
Loop/Services/FoodFinder/FoodFinder_OpenFoodFactsService.swift
Loop/Services/FoodFinder/FoodFinder_ScannerService.swift
Loop/Services/FoodFinder/FoodFinder_SearchRouter.swift
Loop/Services/FoodFinder/FoodFinder_SecureStorage.swift
Loop/Services/FoodFinder/FoodFinder_VoiceService.swift
Loop/View Models/FoodFinder/FoodFinder_SearchViewModel.swift
Loop/Views/FoodFinder/FoodFinder_AICameraView.swift
Loop/Views/FoodFinder/FoodFinder_CarbTrackingDashboard.swift
Loop/Views/FoodFinder/FoodFinder_EntryPoint.swift
Loop/Views/FoodFinder/FoodFinder_FavoritesHelpers.swift
Loop/Views/FoodFinder/FoodFinder_ImageCropView.swift
Loop/Views/FoodFinder/FoodFinder_ScannerView.swift
Loop/Views/FoodFinder/FoodFinder_SearchBar.swift
Loop/Views/FoodFinder/FoodFinder_SearchResultsView.swift
Loop/Views/FoodFinder/FoodFinder_SettingsView.swift
Loop/Views/FoodFinder/FoodFinder_VoiceSearchView.swift
LoopTests/FoodFinder/FoodFinder_BarcodeScannerTests.swift
LoopTests/FoodFinder/FoodFinder_OpenFoodFactsTests.swift
LoopTests/FoodFinder/FoodFinder_VoiceSearchTests.swift
EOF
}

files_for_loop_insights() { cat <<'EOF'
Documentation/LoopInsights/LoopInsights_README.md
Documentation/LoopInsights/LoopInsights_DEVELOPER.md
Documentation/DataLayer/DataLayer_README.md
Documentation/DataLayer/DataLayer_DEVELOPER.md
Loop/Managers/DataLayer/DataLayer_Coordinator.swift
Loop/Managers/LoopInsights/LoopInsights_BackgroundMonitor.swift
Loop/Managers/LoopInsights/LoopInsights_Coordinator.swift
Loop/Models/DataLayer/DataLayer_ConsentModels.swift
Loop/Models/DataLayer/DataLayer_EventModels.swift
Loop/Models/LoopInsights/LoopInsights_MealDebriefModels.swift
Loop/Models/LoopInsights/LoopInsights_MFPModels.swift
Loop/Models/LoopInsights/LoopInsights_Models.swift
Loop/Models/LoopInsights/LoopInsights_Phase5Models.swift
Loop/Models/LoopInsights/LoopInsights_SuggestionRecord.swift
Loop/Resources/DataLayer/DataLayer_FeatureFlags.swift
Loop/Resources/LoopInsights/LoopInsights_FeatureFlags.swift
Loop/Resources/LoopInsights/TestData/tidepool_carb_entries.json
Loop/Resources/LoopInsights/TestData/tidepool_dose_entries.json
Loop/Resources/LoopInsights/TestData/tidepool_glucose_samples.json
Loop/Resources/LoopInsights/TestData/tidepool_therapy_settings.json
Loop/Services/DataLayer/DataLayer_ConsentManager.swift
Loop/Services/DataLayer/DataLayer_EventCollector.swift
Loop/Services/DataLayer/DataLayer_EventStore.swift
Loop/Services/DataLayer/DataLayer_ProviderProtocol.swift
Loop/Services/DataLayer/DataLayer_ReportGenerator.swift
Loop/Services/DataLayer/DataLayer_SecureStorage.swift
Loop/Services/DataLayer/DataLayer_SyncService.swift
Loop/Services/LoopInsights/LoopInsights_AIAnalysis.swift
Loop/Services/LoopInsights/LoopInsights_AIServiceAdapter.swift
Loop/Services/LoopInsights/LoopInsights_AdvancedAnalyzers.swift
Loop/Services/LoopInsights/LoopInsights_AlcoholTracker.swift
Loop/Services/LoopInsights/LoopInsights_BackfillDetector.swift
Loop/Services/LoopInsights/LoopInsights_BehaviorInsightsAnalyzer.swift
Loop/Services/LoopInsights/LoopInsights_CaffeineTracker.swift
Loop/Services/LoopInsights/LoopInsights_CaregiverDigestService.swift
Loop/Services/LoopInsights/LoopInsights_ChatHistoryStore.swift
Loop/Services/LoopInsights/LoopInsights_DataAggregator.swift
Loop/Services/LoopInsights/LoopInsights_FoodResponseAnalyzer.swift
Loop/Services/LoopInsights/LoopInsights_GlucoseUnitContext.swift
Loop/Services/LoopInsights/LoopInsights_GoalStore.swift
Loop/Services/LoopInsights/LoopInsights_HealthKitManager.swift
Loop/Services/LoopInsights/LoopInsights_MealDebriefService.swift
Loop/Services/LoopInsights/LoopInsights_MFPImporter.swift
Loop/Services/LoopInsights/LoopInsights_NightscoutImporter.swift
Loop/Services/LoopInsights/LoopInsights_PreMealAdvisorService.swift
Loop/Services/LoopInsights/LoopInsights_ReportGenerator.swift
Loop/Services/LoopInsights/LoopInsights_SecureStorage.swift
Loop/Services/LoopInsights/LoopInsights_SuggestionStore.swift
Loop/Services/LoopInsights/LoopInsights_TestDataProvider.swift
Loop/Services/LoopInsights/LoopInsights_VoiceService.swift
Loop/View Models/LoopInsights/LoopInsights_ChatViewModel.swift
Loop/View Models/LoopInsights/LoopInsights_DashboardViewModel.swift
Loop/View Models/LoopInsights/LoopInsights_MealInsightsViewModel.swift
Loop/Views/DataLayer/DataLayer_ConsentView.swift
Loop/Views/DataLayer/DataLayer_DashboardView.swift
Loop/Views/LoopInsights/LoopInsights_AGPChartView.swift
Loop/Views/LoopInsights/LoopInsights_AlcoholLogView.swift
Loop/Views/LoopInsights/LoopInsights_BehaviorInsightsView.swift
Loop/Views/LoopInsights/LoopInsights_CaffeineLogView.swift
Loop/Views/LoopInsights/LoopInsights_CaregiverDigestView.swift
Loop/Views/LoopInsights/LoopInsights_ChatHistoryView.swift
Loop/Views/LoopInsights/LoopInsights_ChatView.swift
Loop/Views/LoopInsights/LoopInsights_DashboardView.swift
Loop/Views/LoopInsights/LoopInsights_EndoReportView.swift
Loop/Views/LoopInsights/LoopInsights_GoalsView.swift
Loop/Views/LoopInsights/LoopInsights_MealDebriefCard.swift
Loop/Views/LoopInsights/LoopInsights_MealInsightsView.swift
Loop/Views/LoopInsights/LoopInsights_MonitorSettingsView.swift
Loop/Views/LoopInsights/LoopInsights_PreMealAdvisorCard.swift
Loop/Views/LoopInsights/LoopInsights_SettingsView.swift
Loop/Views/LoopInsights/LoopInsights_SuggestionDetailView.swift
Loop/Views/LoopInsights/LoopInsights_SuggestionHistoryView.swift
Loop/Views/LoopInsights/LoopInsights_TrendsInsightsView.swift
LoopTests/LoopInsights/LoopInsights_DataAggregatorTests.swift
LoopTests/LoopInsights/LoopInsights_ModelsTests.swift
LoopTests/LoopInsights/LoopInsights_SuggestionStoreTests.swift
EOF
}

# Helper: emit the file list for the named feature.
files_for() {
    case "$1" in
        autopresets)        files_for_autopresets ;;
        bolus_pro)          files_for_bolus_pro ;;
        graph_detail_view)  files_for_graph_detail_view ;;
        site_atlas)         files_for_site_atlas ;;
        food_finder)        files_for_food_finder ;;
        loop_insights)      files_for_loop_insights ;;
        *)                  return 1 ;;
    esac
}

# Empty directories worth pruning during uninstall once their files are gone.
empty_dirs_for() {
    case "$1" in
        autopresets)
            echo "Loop/Managers/AutoPresets Loop/Models/AutoPresets Loop/Resources/AutoPresets Loop/Services/AutoPresets Loop/Views/AutoPresets Documentation/AutoPresets" ;;
        bolus_pro)
            echo "Loop/Models/BolusPro Loop/Resources/BolusPro Loop/Services/BolusPro Loop/Views/BolusPro Documentation/BolusPro" ;;
        graph_detail_view)
            echo "Documentation/GraphDetailView" ;;
        site_atlas)
            echo "Loop/Models/SiteAtlas Loop/Services/SiteAtlas Loop/Views/SiteAtlas Documentation/SiteAtlas" ;;
        food_finder)
            echo "Loop/Models/FoodFinder Loop/Resources/FoodFinder Loop/Services/FoodFinder Loop/View\ Models/FoodFinder Loop/Views/FoodFinder LoopTests/FoodFinder Documentation/FoodFinder" ;;
        loop_insights)
            echo "Loop/Managers/DataLayer Loop/Managers/LoopInsights Loop/Models/DataLayer Loop/Models/LoopInsights Loop/Resources/DataLayer Loop/Resources/LoopInsights/TestData Loop/Resources/LoopInsights Loop/Services/DataLayer Loop/Services/LoopInsights Loop/View\ Models/LoopInsights Loop/Views/DataLayer Loop/Views/LoopInsights LoopTests/LoopInsights Documentation/LoopInsights Documentation/DataLayer" ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# 5. GENERIC HELPERS — VALIDATION, SOURCE REMOTE, OMNIBLE BASE
# ─────────────────────────────────────────────────────────────────────────────

validate_environment() {
    [[ -d "LoopWorkspace.xcworkspace" ]] || die "Must run from LoopWorkspace root (LoopWorkspace.xcworkspace not found).
  cd into your LoopWorkspace folder and try again."
    [[ -d "Loop/.git" || -f "Loop/.git" ]] || die "Loop submodule not found. Clone with --recurse-submodules."
    command -v python3 &>/dev/null || die "python3 is required."
    command -v plutil &>/dev/null || die "plutil is required (macOS-only)."
    command -v git &>/dev/null     || die "git is required."
}

ensure_source_remote() {
    pushd Loop > /dev/null
    if ! git remote | grep -q "^${FEATURE_REMOTE}$"; then
        git remote add "$FEATURE_REMOTE" "$FEATURE_REPO"
    fi
    git fetch "$FEATURE_REMOTE" "$FEATURE_INTEGRATION_BRANCH" --depth=50 > /dev/null
    git fetch "$FEATURE_REMOTE" "$FEATURE_DEV_BRANCH"          --depth=50 > /dev/null
    popd > /dev/null
}

apply_omnible_base() {
    if [[ ! -d "OmniBLE/.git" && ! -f "OmniBLE/.git" ]]; then
        warn "OmniBLE submodule not found — skipping pod-keep-alive base init"
        return
    fi
    pushd OmniBLE > /dev/null
    local current; current=$(git rev-parse HEAD 2>/dev/null || echo "")
    if [[ "$current" == "$OMNIBLE_POD_KEEP_ALIVE_SHA" ]]; then
        info "OmniBLE already at pod-keep-alive SHA"
    else
        if git fetch origin pod-keep-alive --depth=1 2>/dev/null && \
           git checkout "$OMNIBLE_POD_KEEP_ALIVE_SHA" 2>/dev/null; then
            success "OmniBLE checked out to pod-keep-alive (DASH iPhone 16/17 fix)"
        else
            warn "Could not check out OmniBLE pod-keep-alive SHA"
        fi
    fi
    popd > /dev/null
}

bump_version_once() {
    if [[ -f "VersionOverride.xcconfig" ]] && ! grep -q "LOOP_MARKETING_VERSION = ${FEATURE_VERSION}" VersionOverride.xcconfig; then
        sed -i '' "s/LOOP_MARKETING_VERSION = .*/LOOP_MARKETING_VERSION = ${FEATURE_VERSION}/" VersionOverride.xcconfig
        sed -i '' "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = ${FEATURE_BUILD}/" VersionOverride.xcconfig
        success "Version bumped to ${FEATURE_VERSION} (${FEATURE_BUILD})"
    fi
}

create_loop_stash_once() {
    pushd Loop > /dev/null
    local has_dirt=0
    if ! git diff --quiet || ! git diff --cached --quiet; then has_dirt=1; fi
    if [[ $has_dirt -eq 1 ]] && ! git stash list 2>/dev/null | grep -q "powerpack-pre-install"; then
        git stash push -m "powerpack-pre-install-$(date +%Y%m%d-%H%M%S)" --include-untracked
        git stash apply 2>/dev/null
        success "Backed up working tree (stash for rollback recovery)"
    fi
    popd > /dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# 6. FILE COPY + DELETE
# ─────────────────────────────────────────────────────────────────────────────

copy_files_for_feature() {
    local fid="$1"
    pushd Loop > /dev/null
    local n=0 fail=0
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if git checkout "${FEATURE_REMOTE}/${FEATURE_INTEGRATION_BRANCH}" -- "$file" 2>/dev/null; then
            ((n++))
        else
            warn "Could not checkout ${file}"
            ((fail++))
        fi
    done < <(files_for "$fid")
    popd > /dev/null
    info "Copied ${n} files for $(feature_name "$fid") (${fail} failed)"
}

delete_files_for_feature() {
    local fid="$1"
    pushd Loop > /dev/null
    local n=0
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        if [[ -f "$file" ]]; then
            rm -f "$file"
            ((n++))
        fi
    done < <(files_for "$fid")
    # Prune empty subdirs
    eval "for d in $(empty_dirs_for "$fid"); do rmdir \"\$d\" 2>/dev/null || true; done"
    popd > /dev/null
    info "Removed ${n} files for $(feature_name "$fid")"
}

# Install SiteAtlas body-map PNGs as imagesets in DerivedAssetsBase.xcassets
install_site_atlas_assets() {
    pushd Loop > /dev/null
    local assets_base="Loop/DerivedAssetsBase.xcassets"
    local tmp_front tmp_back
    tmp_front=$(mktemp); tmp_back=$(mktemp)
    if git show "${FEATURE_REMOTE}/${FEATURE_INTEGRATION_BRANCH}:Loop/Resources/SiteAtlas/BodyMapFront.png" > "$tmp_front" 2>/dev/null && \
       git show "${FEATURE_REMOTE}/${FEATURE_INTEGRATION_BRANCH}:Loop/Resources/SiteAtlas/BodyMapBack.png"  > "$tmp_back"  2>/dev/null; then
        mkdir -p "${assets_base}/BodyMapFront.imageset" "${assets_base}/BodyMapBack.imageset"
        cp "$tmp_front" "${assets_base}/BodyMapFront.imageset/BodyMapFront.png"
        cp "$tmp_back"  "${assets_base}/BodyMapBack.imageset/BodyMapBack.png"
        cat > "${assets_base}/BodyMapFront.imageset/Contents.json" <<'IMG'
{ "images": [ { "filename": "BodyMapFront.png", "idiom": "universal" } ],
  "info":   { "author": "xcode", "version": 1 } }
IMG
        cat > "${assets_base}/BodyMapBack.imageset/Contents.json" <<'IMG'
{ "images": [ { "filename": "BodyMapBack.png", "idiom": "universal" } ],
  "info":   { "author": "xcode", "version": 1 } }
IMG
        success "Installed SiteAtlas body-map imagesets"
    else
        warn "Could not retrieve SiteAtlas body-map PNGs"
    fi
    rm -f "$tmp_front" "$tmp_back"
    popd > /dev/null
}

uninstall_site_atlas_assets() {
    pushd Loop > /dev/null
    local assets_base="Loop/DerivedAssetsBase.xcassets"
    rm -rf "${assets_base}/BodyMapFront.imageset" "${assets_base}/BodyMapBack.imageset"
    popd > /dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# 7. PBXPROJ DRIVER
# update_pbxproj.py supports `--features <ids>` and `--remove-features <ids>`.
# Falls back to local script first, then downloads from raw.githubusercontent.
# ─────────────────────────────────────────────────────────────────────────────

resolve_pbxproj_script() {
    if [[ -f "${SCRIPT_DIR}/update_pbxproj.py" ]]; then
        echo "${SCRIPT_DIR}/update_pbxproj.py"; return
    fi
    if [[ -f "Scripts/update_pbxproj.py" ]]; then
        echo "Scripts/update_pbxproj.py"; return
    fi
    mkdir -p Scripts
    if curl -fsSL "${WORKSPACE_REPO}/Scripts/update_pbxproj.py" -o Scripts/update_pbxproj.py; then
        echo "Scripts/update_pbxproj.py"; return
    fi
    return 1
}

run_pbxproj() {
    local pbx="Loop/Loop.xcodeproj/project.pbxproj"
    [[ -f "$pbx" ]] || die "project.pbxproj not found at $pbx"
    local script; script=$(resolve_pbxproj_script) || die "Could not locate update_pbxproj.py"
    cp "$pbx" "${pbx}.backup"
    if python3 "$script" "$@" "$pbx"; then
        if plutil -lint "$pbx" > /dev/null 2>&1; then
            rm -f "${pbx}.backup"
            success "project.pbxproj updated and validated"
        else
            error "plutil validation failed — restoring backup"
            cp "${pbx}.backup" "$pbx"
            rm -f "${pbx}.backup"
            return 1
        fi
    else
        error "update_pbxproj.py failed — restoring backup"
        cp "${pbx}.backup" "$pbx"
        rm -f "${pbx}.backup"
        return 1
    fi
}

pbxproj_add_feature()    { run_pbxproj --features "$1"; }
pbxproj_remove_feature() { run_pbxproj --remove-features "$1"; }

# ─────────────────────────────────────────────────────────────────────────────
# 8. ANCHOR INSERTION (with BEGIN/END markers per feature)
# Each insert is wrapped in:
#   // BEGIN <Feature> — installer
#   ...
#   // END <Feature> — installer
# Uninstall greps the markers and removes the block.
# ─────────────────────────────────────────────────────────────────────────────

# Generic: remove every block tagged `// BEGIN <marker>` ... `// END <marker>`
remove_anchor_block() {
    local file="$1" marker="$2"
    [[ -f "$file" ]] || return 0
    python3 - "$file" "$marker" <<'PYEOF'
import re, sys
fp, mark = sys.argv[1], sys.argv[2]
with open(fp, 'r') as f:
    text = f.read()
pattern = (
    r'\n?[ \t]*//[ \t]*BEGIN ' + re.escape(mark) + r'[^\n]*\n'
    r'.*?'
    r'[ \t]*//[ \t]*END ' + re.escape(mark) + r'[^\n]*\n?'
)
new_text, n = re.subn(pattern, '\n', text, flags=re.DOTALL)
if n:
    with open(fp, 'w') as f:
        f.write(new_text)
    print(f"  Removed {n} '{mark}' block(s) from {fp}")
PYEOF
}

# Internal helper: read whole file into Python, do an anchor-based insert, write back.
# Args: $1=filepath, $2=marker, $3=anchor regex/string, $4=insert position (after|before),
# $5=block text via stdin
_anchor_insert() {
    local file="$1" marker="$2" anchor="$3" position="$4"
    [[ -f "$file" ]] || { warn "anchor target missing: $file"; return 0; }
    local block; block=$(cat)
    if grep -q "// BEGIN ${marker}" "$file"; then
        info "Anchor block '${marker}' already present in $(basename "$file") — skipping"
        return 0
    fi
    python3 - "$file" "$marker" "$anchor" "$position" "$block" <<'PYEOF'
import sys
fp, marker, anchor, position, block = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
with open(fp, 'r') as f:
    lines = f.read().split('\n')
idx = None
for i, line in enumerate(lines):
    if anchor in line:
        idx = i
        break
if idx is None:
    print(f"  ERROR: anchor not found in {fp}: {anchor!r}", file=sys.stderr)
    sys.exit(2)
wrapped = (
    f"        // BEGIN {marker} — installer\n"
    + block.rstrip('\n') + "\n"
    + f"        // END {marker} — installer"
)
insert_at = idx + 1 if position == 'after' else idx
for j, ln in enumerate(wrapped.split('\n')):
    lines.insert(insert_at + j, ln)
with open(fp, 'w') as f:
    f.write('\n'.join(lines))
print(f"  Inserted '{marker}' block in {fp} at line {insert_at + 1}")
PYEOF
}

# ─── AutoPresets anchor inserts ──────────────────────────────────────────────

insert_settings_view_for_autopresets() {
    _anchor_insert \
        "Loop/Loop/Views/SettingsView.swift" \
        "AutoPresets" \
        "Diabetes Treatment" \
        "after" <<'BLOCK'
            NavigationLink(destination: AutoPresets_SettingsView(dataStoresProvider: viewModel.loopInsightsDataStores)) {
                LargeButton(
                    action: {},
                    includeArrow: false,
                    imageView: AutoPresets_IconView(),
                    label: NSLocalizedString("AutoPresets", comment: "Title text for button to AutoPresets Settings"),
                    descriptiveText: NSLocalizedString("Automate your presets during motion", comment: "Descriptive text for AutoPresets")
                )
            }
BLOCK
}

insert_loop_data_manager_for_autopresets() {
    local file="Loop/Loop/Managers/LoopDataManager.swift"
    [[ -f "$file" ]] || { warn "$file not found"; return 0; }
    if grep -q "// BEGIN AutoPresets" "$file"; then
        info "AutoPresets block already in LoopDataManager.swift — skipping"
        return 0
    fi
    python3 - "$file" <<'PYEOF'
import sys
fp = sys.argv[1]
with open(fp, 'r') as f:
    text = f.read()
lines = text.split('\n')

# Insert delegate-setup line in the init body.
INIT_BLOCK = """
        // BEGIN AutoPresets — installer
        AutoPresets_Coordinator.shared.delegate = self
        // END AutoPresets — installer"""

anchor = "self.trustedTimeOffset = trustedTimeOffset"
idx = next((i for i, ln in enumerate(lines) if anchor in ln), None)
if idx is None:
    print("ERROR: trustedTimeOffset anchor not found", file=sys.stderr); sys.exit(2)
for j, ln in enumerate(INIT_BLOCK.split('\n')):
    lines.insert(idx + 1 + j, ln)

# Append delegate extension at end of file.
EXT = """
// BEGIN AutoPresets — installer
extension LoopDataManager: AutoPresets_Delegate {
    func autoPresets(_ coordinator: AutoPresets_Coordinator,
                     shouldActivatePreset preset: TemporaryScheduleOverridePreset) {
        logger.default("AutoPresets activating preset: %{public}@", preset.name)
        mutateSettings { settings in
            settings.scheduleOverride = preset.createOverride(enactTrigger: .local)
        }
    }
    func autoPresets(_ coordinator: AutoPresets_Coordinator,
                     shouldDeactivatePreset preset: TemporaryScheduleOverridePreset) {
        guard let currentOverride = settings.scheduleOverride,
              case let .preset(currentPreset) = currentOverride.context,
              currentPreset.id == preset.id
        else { return }
        logger.default("AutoPresets deactivating preset: %{public}@", preset.name)
        mutateSettings { settings in settings.scheduleOverride = nil }
    }
    func autoPresets(_ coordinator: AutoPresets_Coordinator,
                     shouldCreatePreset preset: TemporaryScheduleOverridePreset) {
        logger.default("AutoPresets creating AI-recommended preset: %{public}@", preset.name)
        mutateSettings { settings in settings.overridePresets.append(preset) }
    }
    func autoPresetsAvailablePresets(_ coordinator: AutoPresets_Coordinator) -> [TemporaryScheduleOverridePreset] {
        settings.overridePresets
    }
    func autoPresetsCurrentOverride(_ coordinator: AutoPresets_Coordinator) -> TemporaryScheduleOverride? {
        settings.scheduleOverride
    }
}
// END AutoPresets — installer
"""
lines.extend(EXT.split('\n'))
with open(fp, 'w') as f:
    f.write('\n'.join(lines))
print(f"  Inserted AutoPresets blocks in {fp}")
PYEOF
}

# ─── BolusPro anchor inserts ─────────────────────────────────────────────────

insert_settings_view_for_bolus_pro() {
    _anchor_insert \
        "Loop/Loop/Views/SettingsView.swift" \
        "BolusPro" \
        "Diabetes Treatment" \
        "after" <<'BLOCK'
            NavigationLink(destination: BolusPro_SettingsView()) {
                LargeButton(action: {},
                            includeArrow: false,
                            imageView: Image(systemName: "drop.halffull")
                                .foregroundColor(Color(red: 230/255, green: 188/255, blue: 60/255))
                                .font(.system(size: 36)),
                            label: NSLocalizedString("BolusPro", comment: "Title text for button to BolusPro Settings"),
                            descriptiveText: NSLocalizedString("Protein & fat-aware bolusing for long absorption meals", comment: "Descriptive text for BolusPro Settings"))
            }
BLOCK
}

insert_bolus_entry_viewmodel_for_bolus_pro() {
    local file="Loop/Loop/View Models/BolusEntryViewModel.swift"
    [[ -f "$file" ]] || { warn "$file not found"; return 0; }
    if grep -q "// BEGIN BolusPro" "$file"; then
        info "BolusPro block already in BolusEntryViewModel.swift — skipping"
        return 0
    fi
    python3 - "$file" <<'PYEOF'
import sys
fp = sys.argv[1]
with open(fp, 'r') as f:
    text = f.read()
lines = text.split('\n')

PROPS = """
    // BEGIN BolusPro — installer
    var bolusProSecondaryEntry: NewCarbEntry?
    var bolusProAnalyticsSnapshot: BolusProAnalyticsSnapshot?
    // END BolusPro — installer"""
anchor1 = "let selectedCarbAbsorptionTimeEmoji: String?"
i1 = next((i for i, ln in enumerate(lines) if anchor1 in ln), None)
if i1 is None:
    print("ERROR: BolusPro anchor 1 not found", file=sys.stderr); sys.exit(2)
for j, ln in enumerate(PROPS.split('\n')):
    lines.insert(i1 + 1 + j, ln)

SAVE = """
                // BEGIN BolusPro — installer
                if let secondary = bolusProSecondaryEntry {
                    if let storedSecondary = await saveCarbEntry(secondary, replacingEntry: nil) {
                        self.analyticsServicesManager?.didAddCarbs(source: "BolusPro", amount: storedSecondary.quantity.doubleValue(for: .gram()))
                    } else {
                        log.error("BolusPro secondary entry save failed — primary already saved.")
                    }
                }
                if let snapshot = bolusProAnalyticsSnapshot {
                    BolusPro_DataLayerHook.recordSavedEntry(snapshot)
                }
                // END BolusPro — installer"""
anchor2 = 'self.analyticsServicesManager?.didAddCarbs(source: "Phone"'
i2 = next((i for i, ln in enumerate(lines) if anchor2 in ln), None)
if i2 is None:
    print("ERROR: BolusPro anchor 2 not found", file=sys.stderr); sys.exit(2)
for j, ln in enumerate(SAVE.split('\n')):
    lines.insert(i2 + 1 + j, ln)

with open(fp, 'w') as f:
    f.write('\n'.join(lines))
print(f"  Inserted BolusPro blocks in {fp}")
PYEOF
}

insert_carb_entry_view_for_bolus_pro() {
    _anchor_insert \
        "Loop/Loop/Views/CarbEntryView.swift" \
        "BolusPro" \
        "absorptionTimeRow" \
        "after" <<'BLOCK'
            BolusPro_CarbEntrySection(viewModel: viewModel)
BLOCK
}

# ─── GraphDetailView anchor inserts ──────────────────────────────────────────

insert_status_table_view_controller_for_graph_detail_view() {
    local file="Loop/Loop/View Controllers/StatusTableViewController.swift"
    [[ -f "$file" ]] || { warn "$file not found"; return 0; }
    if grep -q "// BEGIN GraphDetailView" "$file"; then
        info "GraphDetailView block already in StatusTableViewController.swift — skipping"
        return 0
    fi
    python3 - "$file" <<'PYEOF'
import sys
fp = sys.argv[1]
with open(fp, 'r') as f:
    text = f.read()
# StatusTableViewController gets a substantial block. We use the existing
# feat/AllFeatures content as the source of truth — installer applies the
# whole long-press handler block once, then wraps the entire thing in a
# BEGIN/END marker for clean removal. This matches what the old monolithic
# installer was doing inline; we delegate to git for the heavy lifting.
import subprocess
diff = subprocess.run(
    ["git", "-C", "Loop", "diff", "_powerpack_src/dev",
     "_powerpack_src/feat/AllFeatures", "--",
     "Loop/View Controllers/StatusTableViewController.swift"],
    capture_output=True, text=True
)
# We can't reliably 3-way-apply only this feature's slice — the per-feature
# branches aren't clean. Instead the install_graph_detail_view function
# directly checks out the file from feat/AllFeatures and brackets the new
# code with markers post-checkout. See install_graph_detail_view().
print("  GraphDetailView edits applied via direct checkout — see install function")
PYEOF
}

# ─── SiteAtlas anchor inserts ────────────────────────────────────────────────

insert_settings_view_for_site_atlas() {
    _anchor_insert \
        "Loop/Loop/Views/SettingsView.swift" \
        "SiteAtlas" \
        "Diabetes Treatment" \
        "after" <<'BLOCK'
            NavigationLink(destination: SiteAtlas_SettingsView()) {
                LargeButton(action: {},
                            includeArrow: false,
                            imageView: Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(Color(red: 230/255, green: 126/255, blue: 34/255))
                                .font(.system(size: 36)),
                            label: NSLocalizedString("Site Atlas", comment: "Title text for button to Site Atlas Settings"),
                            descriptiveText: NSLocalizedString("Track pump and sensor site rotation", comment: "Descriptive text for Site Atlas"))
            }
BLOCK
}

insert_loop_data_manager_for_site_atlas() {
    local file="Loop/Loop/Managers/LoopDataManager.swift"
    [[ -f "$file" ]] || { warn "$file not found"; return 0; }
    if grep -q "// BEGIN SiteAtlas" "$file"; then
        info "SiteAtlas block already in LoopDataManager.swift — skipping"
        return 0
    fi
    _anchor_insert "$file" "SiteAtlas" "self.trustedTimeOffset = trustedTimeOffset" "after" <<'BLOCK'
        _ = SiteAtlas_Coordinator.shared
BLOCK
}

insert_device_data_manager_for_site_atlas() {
    local file="Loop/Loop/Managers/DeviceDataManager.swift"
    [[ -f "$file" ]] || { warn "$file not found"; return 0; }
    if grep -q "// BEGIN SiteAtlas" "$file"; then return 0; fi
    _anchor_insert "$file" "SiteAtlas" "func pumpManagerWillDeactivate" "after" <<'BLOCK'
        NotificationCenter.default.post(name: .pumpSiteDeactivated, object: nil)
BLOCK
}

# ─── FoodFinder anchor inserts ───────────────────────────────────────────────

insert_settings_view_for_food_finder() {
    _anchor_insert \
        "Loop/Loop/Views/SettingsView.swift" \
        "FoodFinder" \
        "Diabetes Treatment" \
        "after" <<'BLOCK'
            NavigationLink(destination: AISettingsView()) {
                LargeButton(action: {},
                            includeArrow: false,
                            imageView: Image(systemName: "fork.knife.circle.fill")
                                .foregroundColor(Color(red: 107/255, green: 47/255, blue: 160/255))
                                .font(.system(size: 36)),
                            label: NSLocalizedString("FoodFinder", comment: "Title text for button to FoodFinder Settings"),
                            descriptiveText: NSLocalizedString("AI-powered & barcode food analysis", comment: "Descriptive text for FoodFinder Settings"))
            }
BLOCK
}

insert_carb_entry_view_for_food_finder() {
    _anchor_insert \
        "Loop/Loop/Views/CarbEntryView.swift" \
        "FoodFinder" \
        "private var standardForm: some View" \
        "before" <<'BLOCK'
        FoodFinder_EntryPoint(viewModel: viewModel)
BLOCK
}

# ─── LoopInsights anchor inserts ─────────────────────────────────────────────

insert_settings_view_for_loop_insights() {
    _anchor_insert \
        "Loop/Loop/Views/SettingsView.swift" \
        "LoopInsights" \
        "Diabetes Treatment" \
        "after" <<'BLOCK'
            Section {
                NavigationLink(destination: LoopInsights_SettingsView(dataStoresProvider: viewModel.loopInsightsDataStores)) {
                    LargeButton(action: {},
                                includeArrow: false,
                                imageView: Image(systemName: "brain.head.profile")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .foregroundColor(Color(red: 26/255, green: 138/255, blue: 158/255))
                                    .frame(width: 30),
                                label: NSLocalizedString("LoopInsights", comment: "LoopInsights settings button"),
                                descriptiveText: NSLocalizedString("AI-powered therapy settings analysis", comment: "LoopInsights settings descriptive text"))
                }
            }
BLOCK
}

insert_settings_view_therapy_help_for_loop_insights() {
    local file="Loop/Loop/Views/SettingsView.swift"
    [[ -f "$file" ]] || return 0
    if grep -q "TherapyHelpRegistry" "$file"; then return 0; fi
    python3 - "$file" <<'PYEOF'
import sys
fp = sys.argv[1]
with open(fp, 'r') as f:
    content = f.read()
old = '.navigationViewStyle(.stack)'
new = old + '''
        // BEGIN LoopInsights — installer
        .onAppear {
            TherapyHelpRegistry.destination = AnyView(LoopInsights_SettingsView(dataStoresProvider: viewModel.loopInsightsDataStores))
        }
        // END LoopInsights — installer'''
if old in content:
    content = content.replace(old, new, 1)
    with open(fp, 'w') as f:
        f.write(content)
    print("  Injected TherapyHelpRegistry into SettingsView.swift")
PYEOF
}

patch_loopkit_for_loop_insights() {
    local dismiss_file="LoopKit/LoopKitUI/Extensions/Environment+Dismiss.swift"
    local therapy_file="LoopKit/LoopKitUI/Views/Settings Editors/TherapySettingsView.swift"

    if [[ -f "$dismiss_file" ]] && ! grep -q "TherapyHelpRegistry" "$dismiss_file"; then
        cat >> "$dismiss_file" <<'EOF'

// BEGIN LoopInsights — installer
public final class TherapyHelpRegistry {
    public static var destination: AnyView? = nil
}
// END LoopInsights — installer
EOF
        success "Patched LoopKit Environment+Dismiss.swift with TherapyHelpRegistry"
    fi

    if [[ -f "$therapy_file" ]] && ! grep -q "TherapyHelpRegistry" "$therapy_file"; then
        python3 - "$therapy_file" <<'PYEOF'
import sys
fp = sys.argv[1]
with open(fp, 'r') as f:
    content = f.read()
old = '''    private var supportSection: some View {
        Section {
            NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
                HStack {
                    Text("Get help with Therapy Settings", comment: "Support button for Therapy Settings")
                        .foregroundColor(.primary)
                    Spacer()
                    Disclosure()
                }
            }
        }
        .contentShape(Rectangle())
    }'''
new = '''    // BEGIN LoopInsights — installer
    private var supportSection: some View {
        Section {
            if let destination = TherapyHelpRegistry.destination {
                NavigationLink(destination: destination) {
                    HStack {
                        Text("Get help with Therapy Settings", comment: "Support button for Therapy Settings")
                            .foregroundColor(.primary)
                        Spacer()
                        Disclosure()
                    }
                }
            } else {
                NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
                    HStack {
                        Text("Get help with Therapy Settings", comment: "Support button for Therapy Settings")
                            .foregroundColor(.primary)
                        Spacer()
                        Disclosure()
                    }
                }
            }
        }
        .contentShape(Rectangle())
    }
    // END LoopInsights — installer'''
if old in content:
    content = content.replace(old, new, 1)
    with open(fp, 'w') as f:
        f.write(content)
    print("  Patched LoopKit TherapySettingsView.swift")
PYEOF
    fi
}

unpatch_loopkit_for_loop_insights() {
    remove_anchor_block "LoopKit/LoopKitUI/Extensions/Environment+Dismiss.swift" "LoopInsights"
    # supportSection: revert by restoring the original block.
    local therapy_file="LoopKit/LoopKitUI/Views/Settings Editors/TherapySettingsView.swift"
    [[ -f "$therapy_file" ]] || return 0
    python3 - "$therapy_file" <<'PYEOF'
import sys
fp = sys.argv[1]
with open(fp, 'r') as f:
    content = f.read()
new = '''    private var supportSection: some View {
        Section {
            NavigationLink(destination: DemoPlaceHolderView(appName: appName)) {
                HStack {
                    Text("Get help with Therapy Settings", comment: "Support button for Therapy Settings")
                        .foregroundColor(.primary)
                    Spacer()
                    Disclosure()
                }
            }
        }
        .contentShape(Rectangle())
    }'''
old_marker_start = "    // BEGIN LoopInsights — installer\n    private var supportSection: some View {"
old_marker_end = "    // END LoopInsights — installer"
import re
pattern = re.compile(re.escape(old_marker_start) + r".*?" + re.escape(old_marker_end), re.DOTALL)
new_content, n = pattern.subn(new, content)
if n:
    with open(fp, 'w') as f:
        f.write(new_content)
    print(f"  Reverted supportSection in {fp}")
PYEOF
}

# ─────────────────────────────────────────────────────────────────────────────
# 9. PER-FEATURE INSTALL FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

install_autopresets() {
    header "Installing $(feature_name autopresets)"
    is_installed autopresets && { info "Already installed — skipping."; return; }
    copy_files_for_feature autopresets
    insert_settings_view_for_autopresets
    insert_loop_data_manager_for_autopresets
    pbxproj_add_feature autopresets
    write_marker autopresets
    success "$(feature_name autopresets) installed."
}

install_bolus_pro() {
    header "Installing $(feature_name bolus_pro)"
    is_installed bolus_pro && { info "Already installed — skipping."; return; }
    copy_files_for_feature bolus_pro
    insert_settings_view_for_bolus_pro
    insert_carb_entry_view_for_bolus_pro
    insert_bolus_entry_viewmodel_for_bolus_pro
    pbxproj_add_feature bolus_pro
    write_marker bolus_pro
    success "$(feature_name bolus_pro) installed."
}

install_graph_detail_view() {
    header "Installing $(feature_name graph_detail_view)"
    is_installed graph_detail_view && { info "Already installed — skipping."; return; }
    copy_files_for_feature graph_detail_view
    # StatusTableViewController gets a sizable block. The per-feature branch
    # diff is not a clean slice, so we apply the AllFeatures version of that
    # one file directly. The new code is bracketed in the source itself with
    # `// MARK: - GraphDetailView (Long-Hold Detail Popup)` for legibility;
    # uninstall reverts via `git checkout dev -- <file>` on that single file.
    pushd Loop > /dev/null
    git checkout "${FEATURE_REMOTE}/${FEATURE_INTEGRATION_BRANCH}" -- \
        "Loop/View Controllers/StatusTableViewController.swift" 2>/dev/null \
        && success "Applied StatusTableViewController gestures for GraphDetailView" \
        || warn "Could not check out StatusTableViewController.swift — manual review needed"
    popd > /dev/null
    pbxproj_add_feature graph_detail_view
    write_marker graph_detail_view
    success "$(feature_name graph_detail_view) installed."
}

install_site_atlas() {
    header "Installing $(feature_name site_atlas)"
    is_installed site_atlas && { info "Already installed — skipping."; return; }
    copy_files_for_feature site_atlas
    install_site_atlas_assets
    insert_settings_view_for_site_atlas
    insert_loop_data_manager_for_site_atlas
    insert_device_data_manager_for_site_atlas
    pbxproj_add_feature site_atlas
    write_marker site_atlas
    success "$(feature_name site_atlas) installed."
}

install_food_finder() {
    header "Installing $(feature_name food_finder)"
    is_installed food_finder && { info "Already installed — skipping."; return; }
    copy_files_for_feature food_finder
    insert_settings_view_for_food_finder
    insert_carb_entry_view_for_food_finder
    # FavoriteFoodDetailView thumbnail integration: applied via direct
    # checkout of the modified file (4-line addition).
    pushd Loop > /dev/null
    git checkout "${FEATURE_REMOTE}/${FEATURE_INTEGRATION_BRANCH}" -- \
        "Loop/Views/FavoriteFoodDetailView.swift" 2>/dev/null || true
    popd > /dev/null
    pbxproj_add_feature food_finder
    write_marker food_finder
    success "$(feature_name food_finder) installed."
    info "  → Configure your AI provider + API key in Settings → FoodFinder Settings."
}

install_loop_insights() {
    header "Installing $(feature_name loop_insights)"
    is_installed loop_insights && { info "Already installed — skipping."; return; }
    copy_files_for_feature loop_insights
    insert_settings_view_for_loop_insights
    insert_settings_view_therapy_help_for_loop_insights
    patch_loopkit_for_loop_insights
    pbxproj_add_feature loop_insights
    write_marker loop_insights
    success "$(feature_name loop_insights) installed."
    info "  → Configure your AI provider + API key in Settings → LoopInsights → Settings."
    info "  → DataLayer is OFF by default. Opt in via Settings → LoopInsights → Data Sharing."
}

install_one() {
    case "$1" in
        autopresets)        install_autopresets ;;
        bolus_pro)          install_bolus_pro ;;
        graph_detail_view)  install_graph_detail_view ;;
        site_atlas)         install_site_atlas ;;
        food_finder)        install_food_finder ;;
        loop_insights)      install_loop_insights ;;
        *)                  die "Unknown feature: $1" ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# 10. PER-FEATURE UNINSTALL FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

uninstall_autopresets() {
    header "Uninstalling $(feature_name autopresets)"
    is_installed autopresets || { info "Not installed — nothing to do."; return; }
    remove_anchor_block "Loop/Loop/Views/SettingsView.swift" "AutoPresets"
    remove_anchor_block "Loop/Loop/Managers/LoopDataManager.swift" "AutoPresets"
    pbxproj_remove_feature autopresets
    delete_files_for_feature autopresets
    remove_marker autopresets
    success "$(feature_name autopresets) uninstalled."
}

uninstall_bolus_pro() {
    header "Uninstalling $(feature_name bolus_pro)"
    is_installed bolus_pro || { info "Not installed — nothing to do."; return; }
    remove_anchor_block "Loop/Loop/Views/SettingsView.swift" "BolusPro"
    remove_anchor_block "Loop/Loop/Views/CarbEntryView.swift" "BolusPro"
    remove_anchor_block "Loop/Loop/View Models/BolusEntryViewModel.swift" "BolusPro"
    pbxproj_remove_feature bolus_pro
    delete_files_for_feature bolus_pro
    remove_marker bolus_pro
    success "$(feature_name bolus_pro) uninstalled."
}

uninstall_graph_detail_view() {
    header "Uninstalling $(feature_name graph_detail_view)"
    is_installed graph_detail_view || { info "Not installed — nothing to do."; return; }
    pushd Loop > /dev/null
    # Restore StatusTableViewController to its dev-branch state.
    git checkout "${FEATURE_REMOTE}/${FEATURE_DEV_BRANCH}" -- \
        "Loop/View Controllers/StatusTableViewController.swift" 2>/dev/null \
        && success "Reverted StatusTableViewController.swift" \
        || warn "Could not revert StatusTableViewController.swift"
    popd > /dev/null
    pbxproj_remove_feature graph_detail_view
    delete_files_for_feature graph_detail_view
    remove_marker graph_detail_view
    success "$(feature_name graph_detail_view) uninstalled."
}

uninstall_site_atlas() {
    header "Uninstalling $(feature_name site_atlas)"
    is_installed site_atlas || { info "Not installed — nothing to do."; return; }
    remove_anchor_block "Loop/Loop/Views/SettingsView.swift" "SiteAtlas"
    remove_anchor_block "Loop/Loop/Managers/LoopDataManager.swift" "SiteAtlas"
    remove_anchor_block "Loop/Loop/Managers/DeviceDataManager.swift" "SiteAtlas"
    uninstall_site_atlas_assets
    pbxproj_remove_feature site_atlas
    delete_files_for_feature site_atlas
    remove_marker site_atlas
    success "$(feature_name site_atlas) uninstalled."
}

uninstall_food_finder() {
    header "Uninstalling $(feature_name food_finder)"
    is_installed food_finder || { info "Not installed — nothing to do."; return; }
    remove_anchor_block "Loop/Loop/Views/SettingsView.swift" "FoodFinder"
    remove_anchor_block "Loop/Loop/Views/CarbEntryView.swift" "FoodFinder"
    pushd Loop > /dev/null
    git checkout "${FEATURE_REMOTE}/${FEATURE_DEV_BRANCH}" -- \
        "Loop/Views/FavoriteFoodDetailView.swift" 2>/dev/null || true
    popd > /dev/null
    pbxproj_remove_feature food_finder
    delete_files_for_feature food_finder
    remove_marker food_finder
    success "$(feature_name food_finder) uninstalled."
}

uninstall_loop_insights() {
    header "Uninstalling $(feature_name loop_insights)"
    is_installed loop_insights || { info "Not installed — nothing to do."; return; }
    remove_anchor_block "Loop/Loop/Views/SettingsView.swift" "LoopInsights"
    unpatch_loopkit_for_loop_insights
    pbxproj_remove_feature loop_insights
    delete_files_for_feature loop_insights
    remove_marker loop_insights
    success "$(feature_name loop_insights) uninstalled."
}

uninstall_one() {
    case "$1" in
        autopresets)        uninstall_autopresets ;;
        bolus_pro)          uninstall_bolus_pro ;;
        graph_detail_view)  uninstall_graph_detail_view ;;
        site_atlas)         uninstall_site_atlas ;;
        food_finder)        uninstall_food_finder ;;
        loop_insights)      uninstall_loop_insights ;;
        *)                  die "Unknown feature: $1" ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────────────
# 11. AI POWERPACK SUITE (bundles the 5 entangled features)
#
# AutoPresets, BolusPro, FoodFinder, LoopInsights, and DataLayer share
# compile-time symbols. LoopInsights ↔ FoodFinder is circular; AutoPresets
# references LoopInsights_SecureStorage / LoopInsights_Coordinator / etc.;
# DataLayer is woven through LoopInsights' services. They cannot be
# installed independently without source-code refactoring, so the
# installer treats them as a single bundle.
# ─────────────────────────────────────────────────────────────────────────────

# Order matters:
#   - loop_insights first so its types are on disk before any cross-referencing
#     feature's wholesale-checkout files land (e.g. GraphDetailView's
#     StatusTableViewController.swift references LoopInsights_BackfillDetector
#     directly).
#   - graph_detail_view last for the same reason — it pulls in a
#     StatusTableViewController that references LoopInsights+DataLayer types.
AI_SUITE_FEATURE_IDS=(loop_insights food_finder bolus_pro autopresets graph_detail_view)
# loop_insights install also brings DataLayer files; there is no separate
# "datalayer" feature to install.

install_ai_suite() {
    header "Installing AI PowerPack Suite (5 features as one bundle)"
    local fid
    for fid in "${AI_SUITE_FEATURE_IDS[@]}"; do
        is_installed "$fid" || install_one "$fid"
    done
    success "AI PowerPack Suite installed."
}

uninstall_ai_suite() {
    header "Uninstalling AI PowerPack Suite"
    local fid
    # Uninstall in reverse order so cross-feature edits unwind cleanly.
    local reversed=()
    local i=$(( ${#AI_SUITE_FEATURE_IDS[@]} - 1 ))
    while [[ $i -ge 0 ]]; do
        reversed+=("${AI_SUITE_FEATURE_IDS[$i]}")
        i=$(( i - 1 ))
    done
    for fid in "${reversed[@]}"; do
        is_installed "$fid" && uninstall_one "$fid"
    done
    success "AI PowerPack Suite uninstalled."
}

# True if every feature in the bundle is currently installed.
ai_suite_installed() {
    local fid
    for fid in "${AI_SUITE_FEATURE_IDS[@]}"; do
        is_installed "$fid" || return 1
    done
    return 0
}

# True if any feature in the bundle is installed (handles half-installed states).
ai_suite_any_installed() {
    local fid
    for fid in "${AI_SUITE_FEATURE_IDS[@]}"; do
        is_installed "$fid" && return 0
    done
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# 12. INTERACTIVE MENU
# ─────────────────────────────────────────────────────────────────────────────

show_powerpack_menu() {
    clear 2>/dev/null || true
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  Loop (AID) PowerPack — Feature Menu                     ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "  ${BOLD}Pick a feature to install:${NC}"
    echo

    local sa_state suite_state
    if is_installed site_atlas; then
        sa_state="${GREEN}✓ installed${NC}"
    else
        sa_state="${DIM}— Body-map tracker for pump/CGM site rotation${NC}"
    fi
    if ai_suite_installed; then
        suite_state="${GREEN}✓ installed${NC}"
    elif ai_suite_any_installed; then
        suite_state="${YELLOW}⚠ partially installed${NC}"
    else
        suite_state="${DIM}— AutoPresets + BolusPro + FoodFinder + LoopInsights + DataLayer + GraphDetailView${NC}"
    fi

    printf "    1. %-22s %b\n" "SiteAtlas"           "$sa_state"
    printf "    2. %-22s %b\n" "AI PowerPack Suite"  "$suite_state"
    echo "                                (These features share code and install together)"
    echo
    echo -e "    ${BOLD}A${NC}. Install ALL (SiteAtlas + AI Suite)"
    echo -e "    ${BOLD}U${NC}. Uninstall a feature"
    echo -e "    ${BOLD}R${NC}. Uninstall ALL (rollback)"
    echo -e "    ${BOLD}Q${NC}. Quit"
    echo
}

show_uninstall_menu() {
    clear 2>/dev/null || true
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  Uninstall a Feature                                     ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo

    # Build a flat list of uninstallable items: SiteAtlas, AI Suite.
    local -a labels=()
    local -a actions=()
    if is_installed site_atlas; then
        labels+=("SiteAtlas")
        actions+=("uninstall_site_atlas")
    fi
    if ai_suite_any_installed; then
        labels+=("AI PowerPack Suite (all 5 + GraphDetailView)")
        actions+=("uninstall_ai_suite")
    fi

    if [[ ${#labels[@]} -eq 0 ]]; then
        echo "    (no PowerPack features currently installed)"
        echo
        read -r -p "    Press Enter to return to main menu..."
        return
    fi

    local i=1
    for label in "${labels[@]}"; do
        printf "    %d. %s\n" "$i" "$label"
        ((i++))
    done
    echo
    echo -e "    ${BOLD}Q${NC}. Back to main menu"
    echo
    read -r -p "  Choose: " choice
    case "$choice" in
        Q|q|"") return ;;
        [1-9])
            local idx=$((choice - 1))
            if [[ $idx -ge 0 && $idx -lt ${#actions[@]} ]]; then
                "${actions[$idx]}"
                read -r -p "  Press Enter to return to main menu..."
            fi
            ;;
    esac
}

powerpack_interactive_loop() {
    while true; do
        show_powerpack_menu
        read -r -p "  Choose [1-2 / A / U / R / Q]: " choice
        case "$choice" in
            1) install_site_atlas;        read -r -p "  Press Enter..." ;;
            2) install_ai_suite;          read -r -p "  Press Enter..." ;;
            A|a)
                install_site_atlas
                install_ai_suite
                read -r -p "  All-features install complete. Press Enter..."
                ;;
            U|u)
                show_uninstall_menu
                ;;
            R|r)
                echo
                read -r -p "  Uninstall ALL installed features? [y/N]: " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    is_installed site_atlas        && uninstall_site_atlas
                    ai_suite_any_installed         && uninstall_ai_suite
                    rm -f "Loop/${LEGACY_MARKER}"
                fi
                read -r -p "  Press Enter to return to main menu..."
                ;;
            Q|q|"")
                cleanup_remote
                farewell
                exit 0
                ;;
            *)
                warn "Invalid choice: $choice"
                sleep 1
                ;;
        esac
    done
}

cleanup_remote() {
    pushd Loop > /dev/null 2>&1 || return
    if git remote | grep -q "^${FEATURE_REMOTE}$"; then
        git remote remove "$FEATURE_REMOTE" 2>/dev/null || true
    fi
    popd > /dev/null
}

farewell() {
    echo
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  Done!${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
    echo
    echo -e "  ${BOLD}Next steps:${NC}"
    echo "    1. Open LoopWorkspace.xcworkspace in Xcode"
    echo "    2. Build and run (Cmd+R)"
    echo "    3. Each installed feature appears in Loop → Settings"
    echo
    echo -e "  ${BOLD}To re-run this installer:${NC}"
    echo "    ./Scripts/install_features.sh"
    echo
}

# ─────────────────────────────────────────────────────────────────────────────
# 13. BOOTSTRAP — full end-to-end flow when user is not yet in a LoopWorkspace
#
# Wraps Loop & Learn's BuildSelectScript so a single curl-piped command can
# walk the user through: Loop core install → optional L&L customizations →
# PowerPack feature install → final instructions to build in Xcode.
# ─────────────────────────────────────────────────────────────────────────────

LL_BUILD_SCRIPT_URL="https://raw.githubusercontent.com/loopandlearn/lnl-scripts/main/BuildSelectScript.sh"
BUILD_LOOP_DIR="${HOME}/Downloads/BuildLoop"

in_loopworkspace() {
    [[ -d "LoopWorkspace.xcworkspace" ]]
}

# After L&L's script exits, look for the newest LoopWorkspace it produced.
find_latest_workspace() {
    if [[ ! -d "$BUILD_LOOP_DIR" ]]; then
        return 1
    fi
    local newest
    newest=$(cd "$BUILD_LOOP_DIR" && ls -dt */LoopWorkspace 2>/dev/null | head -1)
    [[ -n "$newest" ]] && echo "${BUILD_LOOP_DIR}/${newest}"
}

show_top_menu() {
    clear 2>/dev/null || true
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  Loop (AID) PowerPack Installer                          ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "  You're not in a LoopWorkspace folder yet. Choose your install path:"
    echo
    echo -e "    ${BOLD}1${NC}. Fresh install ${DIM}(recommended for new users)${NC}"
    echo "        → Installs Loop core, optionally applies L&L customizations,"
    echo "          then drops you into the PowerPack feature menu."
    echo
    echo -e "    ${BOLD}2${NC}. I already have a LoopWorkspace somewhere — show me where to run this"
    echo
    echo -e "    ${BOLD}Q${NC}. Quit"
    echo
}

run_ll_bootstrap() {
    header "Step 1 of 2: Loop core + L&L customizations"
    echo
    echo "  Launching the Loop & Learn BuildSelectScript."
    echo "  • Choose ${BOLD}Build Loop${NC}, select the ${BOLD}main${NC} branch."
    echo "  • Apply any L&L customizations you want (Profiles, Basal Lock, etc.),"
    echo "    or skip if you don't want any."
    echo "  • When the L&L script exits, this installer will resume."
    echo
    read -r -p "  Press Enter to launch L&L BuildSelectScript..."
    echo

    # Run L&L's script. It clones into ~/Downloads/BuildLoop/Loop-<timestamp>/LoopWorkspace
    # and handles its own customization menu.
    /bin/bash -c "$(curl -fsSL "$LL_BUILD_SCRIPT_URL")" || die "L&L BuildSelectScript failed."

    header "Step 2 of 2: PowerPack features"
    local ws
    ws=$(find_latest_workspace) || die "Couldn't find a fresh LoopWorkspace under ${BUILD_LOOP_DIR}. Did the L&L install succeed?"
    cd "$ws" || die "Couldn't cd into $ws"
    success "Found LoopWorkspace: $ws"

    init_common
    powerpack_interactive_loop
}

run_locate_existing() {
    echo
    echo "  Open Terminal, cd into your LoopWorkspace folder, and re-run:"
    echo
    echo "    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/LoopPowerPack/LoopWorkspace/feat/installer/Scripts/install_features.sh)\""
    echo
    exit 0
}

bootstrap_dispatch() {
    while true; do
        show_top_menu
        read -r -p "  Choose [1-2 / Q]: " choice
        case "$choice" in
            1) run_ll_bootstrap; return ;;
            2) run_locate_existing ;;
            Q|q|"") exit 0 ;;
            *) warn "Invalid choice: $choice"; sleep 1 ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# 14. CLI FLAG HANDLERS
# ─────────────────────────────────────────────────────────────────────────────

cli_install_all() {
    install_site_atlas
    install_ai_suite
    cleanup_remote
    farewell
}

cli_install_feature() {
    case "$1" in
        site_atlas)         install_site_atlas ;;
        ai_suite|all|suite) install_ai_suite ;;
        autopresets|bolus_pro|food_finder|loop_insights|graph_detail_view)
            warn "'$1' belongs to the AI PowerPack Suite bundle (entangled with other features)."
            warn "Installing the full bundle. Use --feature ai_suite for the same effect."
            install_ai_suite
            ;;
        *) die "Unknown feature: $1" ;;
    esac
    cleanup_remote
    echo; success "Feature install complete."
}

cli_uninstall_all() {
    is_installed site_atlas        && uninstall_site_atlas
    ai_suite_any_installed         && uninstall_ai_suite
    rm -f "Loop/${LEGACY_MARKER}"
    cleanup_remote
    echo; success "Rollback complete. All PowerPack features removed."
}

cli_uninstall_feature() {
    case "$1" in
        site_atlas)         uninstall_site_atlas ;;
        ai_suite|all|suite) uninstall_ai_suite ;;
        autopresets|bolus_pro|food_finder|loop_insights|graph_detail_view)
            warn "'$1' belongs to the AI PowerPack Suite bundle. Uninstalling the whole bundle."
            uninstall_ai_suite
            ;;
        *) die "Unknown feature: $1" ;;
    esac
    cleanup_remote
    echo; success "Feature uninstall complete."
}

# ─────────────────────────────────────────────────────────────────────────────
# 15. INIT — common to every code path
# ─────────────────────────────────────────────────────────────────────────────

init_common() {
    validate_environment
    ensure_source_remote
    apply_omnible_base
    bump_version_once
    create_loop_stash_once
}

# ─────────────────────────────────────────────────────────────────────────────
# 16. MAIN
# ─────────────────────────────────────────────────────────────────────────────

main() {
    local mode="interactive"
    local feature=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all)         mode="install_all"; shift ;;
            --rollback)    mode="uninstall_all"; shift ;;
            --feature)     mode="install_feature"; feature="$2"; shift 2 ;;
            --uninstall)   mode="uninstall_feature"; feature="$2"; shift 2 ;;
            -h|--help)
                sed -n '2,20p' "${BASH_SOURCE[0]:-$0}" | sed 's|^# \?||'
                exit 0
                ;;
            *)
                die "Unknown argument: $1"
                ;;
        esac
    done

    case "$mode" in
        interactive)
            if in_loopworkspace; then
                init_common
                powerpack_interactive_loop
            else
                bootstrap_dispatch
            fi
            ;;
        install_all)        init_common; cli_install_all ;;
        install_feature)    init_common; cli_install_feature "$feature" ;;
        uninstall_all)      init_common; cli_uninstall_all ;;
        uninstall_feature)  init_common; cli_uninstall_feature "$feature" ;;
    esac
}

main "$@"
