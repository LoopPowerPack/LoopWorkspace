#!/usr/bin/env bash
# install_features.sh — Loop (AID) PowerPack installer (all-or-nothing bundle)
#
# FULL FLOW
#   Loop core + (optional) L&L customizations + PowerPack bundle + build.
#   Run with no args, anywhere, and the installer walks you through it.
#
# WHAT GETS INSTALLED
#   Every PowerPack feature, in one shot. Individual features can't be
#   installed in isolation because they share compile-time symbols. After
#   install, each feature defaults to OFF — turn the ones you want on in
#   Loop → Settings.
#
#   Bundle contents:
#     AutoPresets, BolusPro, FoodFinder, LoopInsights, DataLayer,
#     GraphDetailView, SiteAtlas.
#
# USAGE
#   ./Scripts/install_features.sh              interactive (default)
#   ./Scripts/install_features.sh --install    install non-interactively
#   ./Scripts/install_features.sh --rollback   uninstall non-interactively
#
# ONE-LINER (anywhere — installer detects whether you're in a LoopWorkspace):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/LoopPowerPack/LoopWorkspace/feat/installer/Scripts/install_features.sh)"
#
# Idea by Taylor Patterson. Coded by Claude Code.
# Copyright © 2026 LoopKit Authors and Taylor Patterson.

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────

FEATURE_REMOTE="_feature_src"
FEATURE_BRANCH="feat/installer"
FEATURE_LOOP_BRANCH="feat/AllFeatures"
FEATURE_REPO="https://github.com/LoopPowerPack/Loop.git"
FEATURE_WORKSPACE_REPO="https://raw.githubusercontent.com/LoopPowerPack/LoopWorkspace/${FEATURE_BRANCH}"
MARKER_FILE=".feature_install_marker"

# OmniBLE pod-keep-alive: fixes DASH connectivity on iPhone 16/17 with InPlay BLE (Atlas) pods
OMNIBLE_POD_KEEP_ALIVE_SHA="dade6ed309eb72232a187d88179a367e34f800d9"

# Version to stamp after installation
FEATURE_VERSION="3.13.1"
FEATURE_BUILD="58"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─── New files (don't exist in standard Loop) ────────────────────────────────

NEW_FILES=(
    # Documentation
    "Documentation/FoodFinder/FoodFinder_README.md"
    "Documentation/LoopInsights/LoopInsights_README.md"

    # AutoPresets — Managers
    "Loop/Managers/AutoPresets/AutoPresets_ActivityDetectionManager.swift"
    "Loop/Managers/AutoPresets/AutoPresets_Coordinator.swift"
    "Loop/Managers/AutoPresets/AutoPresets_Delegate.swift"
    "Loop/Managers/AutoPresets/AutoPresets_GeofenceManager.swift"
    "Loop/Managers/AutoPresets/AutoPresets_CalendarManager.swift"
    "Loop/Managers/AutoPresets/AutoPresets_Logger.swift"
    "Loop/Managers/AutoPresets/AutoPresets_Storage.swift"

    # GraphDetailView — Managers
    "Loop/Managers/GraphDetailViewModel.swift"

    # LoopInsights — Managers
    "Loop/Managers/LoopInsights/LoopInsights_BackgroundMonitor.swift"
    "Loop/Managers/LoopInsights/LoopInsights_Coordinator.swift"

    # AutoPresets — Models
    "Loop/Models/AutoPresets/AutoPresets_Models.swift"
    "Loop/Models/AutoPresets/AutoPresets_RecommendationModels.swift"

    # AutoPresets — Services
    "Loop/Services/AutoPresets/AutoPresets_AIAdvisor.swift"

    # FoodFinder — Models
    "Loop/Models/FoodFinder/FoodFinder_AnalysisRecord.swift"
    "Loop/Models/FoodFinder/FoodFinder_InputResults.swift"
    "Loop/Models/FoodFinder/FoodFinder_Models.swift"

    # LoopInsights — Models
    "Loop/Models/LoopInsights/LoopInsights_Models.swift"
    "Loop/Models/LoopInsights/LoopInsights_MFPModels.swift"
    "Loop/Models/LoopInsights/LoopInsights_Phase5Models.swift"
    "Loop/Models/LoopInsights/LoopInsights_SuggestionRecord.swift"

    # FoodFinder — Resources
    "Loop/Resources/FoodFinder/FoodFinder_FeatureFlags.swift"

    # LoopInsights — Resources
    "Loop/Resources/LoopInsights/LoopInsights_FeatureFlags.swift"
    "Loop/Resources/LoopInsights/TestData/tidepool_carb_entries.json"
    "Loop/Resources/LoopInsights/TestData/tidepool_dose_entries.json"
    "Loop/Resources/LoopInsights/TestData/tidepool_glucose_samples.json"
    "Loop/Resources/LoopInsights/TestData/tidepool_therapy_settings.json"

    # FoodFinder — Services
    "Loop/Services/FoodFinder/FoodFinder_CarbTrackingService.swift"
    "Loop/Services/FoodFinder/FoodFinder_AIAnalysis.swift"
    "Loop/Services/FoodFinder/FoodFinder_AIProviderConfig.swift"
    "Loop/Services/FoodFinder/FoodFinder_AIServiceAdapter.swift"
    "Loop/Services/FoodFinder/FoodFinder_AIServiceManager.swift"
    "Loop/Services/FoodFinder/FoodFinder_AnalysisHistoryStore.swift"
    "Loop/Services/FoodFinder/FoodFinder_EmojiProvider.swift"
    "Loop/Services/FoodFinder/FoodFinder_ImageDownloader.swift"
    "Loop/Services/FoodFinder/FoodFinder_ImageStore.swift"
    "Loop/Services/FoodFinder/FoodFinder_LocationService.swift"
    "Loop/Services/FoodFinder/FoodFinder_OpenFoodFactsService.swift"
    "Loop/Services/FoodFinder/FoodFinder_ScannerService.swift"
    "Loop/Services/FoodFinder/FoodFinder_SearchRouter.swift"
    "Loop/Services/FoodFinder/FoodFinder_SecureStorage.swift"
    "Loop/Services/FoodFinder/FoodFinder_VoiceService.swift"

    # LoopInsights — Services
    "Loop/Services/LoopInsights/LoopInsights_AdvancedAnalyzers.swift"
    "Loop/Services/LoopInsights/LoopInsights_AIAnalysis.swift"
    "Loop/Services/LoopInsights/LoopInsights_AIServiceAdapter.swift"
    "Loop/Services/LoopInsights/LoopInsights_AlcoholTracker.swift"
    "Loop/Services/LoopInsights/LoopInsights_ChatHistoryStore.swift"
    "Loop/Services/LoopInsights/LoopInsights_CaffeineTracker.swift"
    "Loop/Services/LoopInsights/LoopInsights_VoiceService.swift"
    "Loop/Services/LoopInsights/LoopInsights_BackfillDetector.swift"
    "Loop/Services/LoopInsights/LoopInsights_BehaviorInsightsAnalyzer.swift"
    "Loop/Services/LoopInsights/LoopInsights_CaregiverDigestService.swift"
    "Loop/Services/LoopInsights/LoopInsights_DataAggregator.swift"
    "Loop/Services/LoopInsights/LoopInsights_FoodResponseAnalyzer.swift"
    "Loop/Services/LoopInsights/LoopInsights_GlucoseUnitContext.swift"
    "Loop/Services/LoopInsights/LoopInsights_GoalStore.swift"
    "Loop/Services/LoopInsights/LoopInsights_HealthKitManager.swift"
    "Loop/Services/LoopInsights/LoopInsights_NightscoutImporter.swift"
    "Loop/Services/LoopInsights/LoopInsights_ReportGenerator.swift"
    "Loop/Services/LoopInsights/LoopInsights_SecureStorage.swift"
    "Loop/Services/LoopInsights/LoopInsights_SuggestionStore.swift"
    "Loop/Services/LoopInsights/LoopInsights_TestDataProvider.swift"
    "Loop/Services/LoopInsights/LoopInsights_MealDebriefService.swift"
    "Loop/Services/LoopInsights/LoopInsights_MFPImporter.swift"
    "Loop/Services/LoopInsights/LoopInsights_PreMealAdvisorService.swift"

    # FoodFinder — View Models
    "Loop/View Models/FoodFinder/FoodFinder_SearchViewModel.swift"

    # LoopInsights — View Models
    "Loop/View Models/LoopInsights/LoopInsights_ChatViewModel.swift"
    "Loop/View Models/LoopInsights/LoopInsights_DashboardViewModel.swift"
    "Loop/View Models/LoopInsights/LoopInsights_MealInsightsViewModel.swift"

    # AutoPresets — Views
    "Loop/Views/AutoPresets/AutoPresets_AIRecommendationView.swift"
    "Loop/Views/AutoPresets/AutoPresets_GeofenceSettingsView.swift"
    "Loop/Views/AutoPresets/AutoPresets_CalendarSettingsView.swift"
    "Loop/Views/AutoPresets/AutoPresets_SettingsView.swift"

    # AutoPresets — Resources
    "Loop/Resources/AutoPresets/AutoPresets_FeatureFlags.swift"

    # BolusPro — Documentation
    "Documentation/BolusPro/BolusPro_README.md"
    "Documentation/BolusPro/BolusPro_DEVELOPER.md"

    # BolusPro — Models
    "Loop/Models/BolusPro/BolusPro_Models.swift"

    # BolusPro — Resources
    "Loop/Resources/BolusPro/BolusPro_FeatureFlags.swift"

    # BolusPro — Services
    "Loop/Services/BolusPro/BolusPro_FPUCalculator.swift"
    "Loop/Services/BolusPro/BolusPro_DataLayerHook.swift"
    "Loop/Services/BolusPro/BolusPro_BehaviorAnalyzer.swift"

    # BolusPro — Views
    "Loop/Views/BolusPro/BolusPro_InfoSheet.swift"
    "Loop/Views/BolusPro/BolusPro_OnboardingView.swift"
    "Loop/Views/BolusPro/BolusPro_ManualMacroFields.swift"
    "Loop/Views/BolusPro/BolusPro_CarbEntrySection.swift"
    "Loop/Views/BolusPro/BolusPro_SettingsView.swift"

    # GraphDetailView — Views
    "Loop/Views/GraphDetailView.swift"

    # FoodFinder — Views
    "Loop/Views/FoodFinder/FoodFinder_CarbTrackingDashboard.swift"
    "Loop/Views/FoodFinder/FoodFinder_AICameraView.swift"
    "Loop/Views/FoodFinder/FoodFinder_ImageCropView.swift"
    "Loop/Views/FoodFinder/FoodFinder_EntryPoint.swift"
    "Loop/Views/FoodFinder/FoodFinder_FavoritesHelpers.swift"
    "Loop/Views/FoodFinder/FoodFinder_ScannerView.swift"
    "Loop/Views/FoodFinder/FoodFinder_SearchBar.swift"
    "Loop/Views/FoodFinder/FoodFinder_SearchResultsView.swift"
    "Loop/Views/FoodFinder/FoodFinder_SettingsView.swift"
    "Loop/Views/FoodFinder/FoodFinder_VoiceSearchView.swift"

    # LoopInsights — Views
    "Loop/Views/LoopInsights/LoopInsights_AGPChartView.swift"
    "Loop/Views/LoopInsights/LoopInsights_AlcoholLogView.swift"
    "Loop/Views/LoopInsights/LoopInsights_BehaviorInsightsView.swift"
    "Loop/Views/LoopInsights/LoopInsights_CaregiverDigestView.swift"
    "Loop/Views/LoopInsights/LoopInsights_EndoReportView.swift"
    "Loop/Views/LoopInsights/LoopInsights_ChatHistoryView.swift"
    "Loop/Views/LoopInsights/LoopInsights_CaffeineLogView.swift"
    "Loop/Views/LoopInsights/LoopInsights_ChatView.swift"
    "Loop/Views/LoopInsights/LoopInsights_DashboardView.swift"
    "Loop/Views/LoopInsights/LoopInsights_GoalsView.swift"
    "Loop/Views/LoopInsights/LoopInsights_MealInsightsView.swift"
    "Loop/Views/LoopInsights/LoopInsights_MonitorSettingsView.swift"
    "Loop/Views/LoopInsights/LoopInsights_SettingsView.swift"
    "Loop/Views/LoopInsights/LoopInsights_SuggestionDetailView.swift"
    "Loop/Views/LoopInsights/LoopInsights_SuggestionHistoryView.swift"
    "Loop/Views/LoopInsights/LoopInsights_TrendsInsightsView.swift"
    "Loop/Views/LoopInsights/LoopInsights_MealDebriefCard.swift"
    "Loop/Views/LoopInsights/LoopInsights_PreMealAdvisorCard.swift"

    # LoopInsights — Models
    "Loop/Models/LoopInsights/LoopInsights_MealDebriefModels.swift"

    # DataLayer — Managers
    "Loop/Managers/DataLayer/DataLayer_Coordinator.swift"

    # DataLayer — Models
    "Loop/Models/DataLayer/DataLayer_EventModels.swift"
    "Loop/Models/DataLayer/DataLayer_ConsentModels.swift"

    # DataLayer — Resources
    "Loop/Resources/DataLayer/DataLayer_FeatureFlags.swift"

    # DataLayer — Services
    "Loop/Services/DataLayer/DataLayer_SecureStorage.swift"
    "Loop/Services/DataLayer/DataLayer_ConsentManager.swift"
    "Loop/Services/DataLayer/DataLayer_EventStore.swift"
    "Loop/Services/DataLayer/DataLayer_EventCollector.swift"
    "Loop/Services/DataLayer/DataLayer_SyncService.swift"
    "Loop/Services/DataLayer/DataLayer_ReportGenerator.swift"
    "Loop/Services/DataLayer/DataLayer_ProviderProtocol.swift"

    # DataLayer — Views
    "Loop/Views/DataLayer/DataLayer_ConsentView.swift"
    "Loop/Views/DataLayer/DataLayer_DashboardView.swift"

    # AutoPresets — Documentation
    "Documentation/AutoPresets/AutoPresets_README.md"
    "Documentation/AutoPresets/AutoPresets_DEVELOPER.md"

    # FoodFinder — Documentation (DEVELOPER added in Batch 3)
    "Documentation/FoodFinder/FoodFinder_DEVELOPER.md"

    # LoopInsights — Documentation (DEVELOPER added in Batch 3)
    "Documentation/LoopInsights/LoopInsights_DEVELOPER.md"

    # DataLayer — Documentation (new in Batch 3)
    "Documentation/DataLayer/DataLayer_README.md"
    "Documentation/DataLayer/DataLayer_DEVELOPER.md"

    # GraphDetailView — Documentation (new in Batch 3)
    "Documentation/GraphDetailView/GraphDetailView_README.md"
    "Documentation/GraphDetailView/GraphDetailView_DEVELOPER.md"

    # SiteAtlas — Documentation (renamed in Batch 3)
    "Documentation/SiteAtlas/SiteAtlas_DEVELOPER.md"
    "Documentation/SiteAtlas/SiteAtlas_README.md"

    # SiteAtlas — Models
    "Loop/Models/SiteAtlas/SiteAtlas_Models.swift"

    # SiteAtlas — Services
    "Loop/Services/SiteAtlas/SiteAtlas_Coordinator.swift"
    "Loop/Services/SiteAtlas/SiteAtlas_FeatureFlags.swift"
    "Loop/Services/SiteAtlas/SiteAtlas_Storage.swift"

    # SiteAtlas — Views
    "Loop/Views/SiteAtlas/SiteAtlas_BodyMapView.swift"
    "Loop/Views/SiteAtlas/SiteAtlas_SettingsView.swift"
    "Loop/Views/SiteAtlas/SiteAtlas_SiteSelectionSheet.swift"

    # FoodFinder — Tests
    "LoopTests/FoodFinder/FoodFinder_BarcodeScannerTests.swift"
    "LoopTests/FoodFinder/FoodFinder_OpenFoodFactsTests.swift"
    "LoopTests/FoodFinder/FoodFinder_VoiceSearchTests.swift"

    # LoopInsights — Tests
    "LoopTests/LoopInsights/LoopInsights_DataAggregatorTests.swift"
    "LoopTests/LoopInsights/LoopInsights_ModelsTests.swift"
    "LoopTests/LoopInsights/LoopInsights_SuggestionStoreTests.swift"
)

# Modified files to patch via git diff | git apply --3way
# Excludes: project.pbxproj (handled by Python script), SettingsView.swift (anchor-based),
# LoopDataManager.swift (anchor-based — L&L Customizations modify this file heavily),
# and Localizable.xcstrings (direct checkout — too large for 3-way merge on JSON)
PATCH_FILES=(
    "Loop/View Controllers/StatusTableViewController.swift"
    "Loop/View Models/AddEditFavoriteFoodViewModel.swift"
    "Loop/View Models/CarbEntryViewModel.swift"
    "Loop/View Models/SettingsViewModel.swift"
    "Loop/Views/AddEditFavoriteFoodView.swift"
    "Loop/Views/CarbEntryView.swift"
    "Loop/Views/FavoriteFoodDetailView.swift"
    "Loop/Views/FavoriteFoodsView.swift"
)

# Files that should be wholesale-replaced from feat/AllFeatures rather than
# patched via 3-way merge. Use sparingly — only for files where L&L
# customizations cannot conflict.
OVERRIDE_FILES=(
)

# ─── Helpers ──────────────────────────────────────────────────────────────────

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*"; }
header()  { echo -e "\n${BOLD}═══ $* ═══${NC}"; }

die() {
    error "$@"
    exit 1
}

# ─── Phase 1: Validation ─────────────────────────────────────────────────────

validate_environment() {
    header "Phase 1: Validating environment"

    # Must run from LoopWorkspace root
    if [[ ! -d "LoopWorkspace.xcworkspace" ]]; then
        die "Must run from LoopWorkspace root directory (LoopWorkspace.xcworkspace not found).
  cd into your LoopWorkspace folder and try again."
    fi
    success "Running from LoopWorkspace root"

    # Loop submodule must exist
    if [[ ! -d "Loop/.git" ]] && [[ ! -f "Loop/.git" ]]; then
        die "Loop submodule not found. Make sure you've cloned with --recurse-submodules."
    fi
    success "Loop submodule exists"

    # python3 available
    if ! command -v python3 &>/dev/null; then
        die "python3 is required but not found. Install Python 3 and try again."
    fi
    success "python3 available ($(python3 --version 2>&1))"

    # Check for existing feature files (idempotency)
    if [[ -f "Loop/${MARKER_FILE}" ]]; then
        die "Features are already installed (marker file found).
  To reinstall, run: ./Scripts/install_features.sh --rollback  first."
    fi

    local sample_files=(
        "Loop/Loop/Views/FoodFinder/FoodFinder_EntryPoint.swift"
        "Loop/Loop/Views/LoopInsights/LoopInsights_DashboardView.swift"
        "Loop/Loop/Views/AutoPresets/AutoPresets_SettingsView.swift"
    )
    for f in "${sample_files[@]}"; do
        if [[ -f "$f" ]]; then
            die "Feature files already exist ($f found).
  To reinstall, run: ./Scripts/install_features.sh --rollback  first."
        fi
    done
    success "No existing feature files found"

    # Verify SettingsView.swift anchors exist
    local settings_file="Loop/Loop/Views/SettingsView.swift"
    if [[ ! -f "$settings_file" ]]; then
        die "SettingsView.swift not found at expected path."
    fi

    if ! grep -q 'Diabetes Treatment' "$settings_file"; then
        die "Anchor not found in SettingsView.swift: Diabetes Treatment
  Your Loop version may be incompatible."
    fi

    if ! grep -q 'private var cgmChoices' "$settings_file"; then
        die "Anchor not found in SettingsView.swift: private var cgmChoices
  Your Loop version may be incompatible."
    fi
    success "SettingsView.swift anchors verified"

    # Detect L&L patches (informational only)
    detect_ll_patches
}

detect_ll_patches() {
    local settings_file="Loop/Loop/Views/SettingsView.swift"
    local found_patches=()

    if grep -q "ProfileManager\|Profiles" "$settings_file" 2>/dev/null; then
        found_patches+=("Profiles")
    fi

    if grep -q "basalLock\|BasalLock\|basal_lock" "Loop/Loop/Managers/LoopDataManager.swift" 2>/dev/null; then
        found_patches+=("Basal Lock")
    fi

    if grep -q "negativeInsulin\|NegativeInsulin\|negative_insulin" "Loop/Loop/Managers/LoopDataManager.swift" 2>/dev/null; then
        found_patches+=("Negative Insulin")
    fi

    local carb_file="Loop/Loop/Views/CarbEntryView.swift"
    if grep -q "futureCarb\|FutureCarb\|future_carb_4h\|absorptionTimeWasEdited" "$carb_file" 2>/dev/null; then
        found_patches+=("Future Carbs 4h")
    fi

    if [[ ${#found_patches[@]} -gt 0 ]]; then
        info "Detected L&L patches: ${found_patches[*]}"
        info "These are compatible — the installer will adapt to them."
    else
        info "No L&L patches detected (standard Loop)."
    fi
}

# ─── Phase 2: Backup ─────────────────────────────────────────────────────────

create_backup() {
    header "Phase 2: Creating backup"

    pushd Loop > /dev/null

    # Stash any uncommitted changes (including L&L patches) as a safety backup,
    # then immediately restore them so L&L patches remain in the working tree
    # during installation. The stash entry stays for rollback.
    local stash_msg="pre-feature-install-$(date +%Y%m%d-%H%M%S)"
    if ! git diff --quiet || ! git diff --cached --quiet; then
        git stash push -m "$stash_msg" --include-untracked
        git stash apply 2>/dev/null
        success "Backed up working tree as: $stash_msg (L&L patches preserved)"
    else
        info "Working tree clean, no stash needed."
    fi

    popd > /dev/null
}

# ─── Phase 3: Fetch Source ────────────────────────────────────────────────────

setup_source_remote() {
    header "Phase 3: Fetching feature source"

    pushd Loop > /dev/null

    # Remove stale remote if it exists
    if git remote | grep -q "^${FEATURE_REMOTE}$"; then
        git remote remove "$FEATURE_REMOTE"
    fi

    git remote add "$FEATURE_REMOTE" "$FEATURE_REPO"
    git fetch "$FEATURE_REMOTE" "$FEATURE_LOOP_BRANCH" --depth=1
    success "Fetched ${FEATURE_LOOP_BRANCH} from ${FEATURE_REPO}"

    # Also fetch dev — our feature branch was based on dev, so we need it as the diff base
    # even when the user cloned main (which is the L&L-compatible path)
    git fetch "$FEATURE_REMOTE" dev --depth=1
    success "Fetched dev ref for diff base"

    popd > /dev/null
}

# ─── Phase 3b: Update OmniBLE to pod-keep-alive ─────────────────────────────

update_omnible() {
    header "Phase 3b: Updating OmniBLE to pod-keep-alive"

    if [[ ! -d "OmniBLE/.git" ]] && [[ ! -f "OmniBLE/.git" ]]; then
        warn "OmniBLE submodule not found — skipping pod-keep-alive update"
        return
    fi

    pushd OmniBLE > /dev/null

    # Fetch the pod-keep-alive branch from upstream
    git fetch origin pod-keep-alive --depth=1 2>/dev/null || {
        warn "Could not fetch pod-keep-alive branch from OmniBLE — skipping"
        popd > /dev/null
        return
    }

    git checkout "$OMNIBLE_POD_KEEP_ALIVE_SHA" 2>/dev/null || {
        warn "Could not checkout OmniBLE pod-keep-alive SHA — skipping"
        popd > /dev/null
        return
    }

    popd > /dev/null
    success "OmniBLE updated to pod-keep-alive (DASH connectivity fix)"
}

# ─── Phase 3c: Bump version ─────────────────────────────────────────────────

bump_version() {
    header "Phase 3c: Setting version to ${FEATURE_VERSION} (${FEATURE_BUILD})"

    if [[ -f "VersionOverride.xcconfig" ]]; then
        sed -i '' "s/LOOP_MARKETING_VERSION = .*/LOOP_MARKETING_VERSION = ${FEATURE_VERSION}/" VersionOverride.xcconfig
        sed -i '' "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = ${FEATURE_BUILD}/" VersionOverride.xcconfig
        success "Version set to ${FEATURE_VERSION} build ${FEATURE_BUILD}"
    else
        warn "VersionOverride.xcconfig not found — version not updated"
    fi
}

# ─── Phase 4: Install New Files ──────────────────────────────────────────────

install_new_files() {
    header "Phase 4: Installing ${#NEW_FILES[@]} new files"

    pushd Loop > /dev/null

    local installed=0
    local failed=0

    for file in "${NEW_FILES[@]}"; do
        if git checkout "${FEATURE_REMOTE}/${FEATURE_LOOP_BRANCH}" -- "$file" 2>/dev/null; then
            ((installed++))
        else
            warn "Failed to checkout: $file"
            ((failed++))
        fi
    done

    # Localizable.xcstrings: direct checkout instead of 3-way merge
    # (71K-line JSON file — too large for reliable diff/apply)
    # Only replace if the user already has it (dev branch uses xcstrings;
    # main branch uses old-style .strings files and doesn't have xcstrings)
    if [[ -f "Loop/Localizable.xcstrings" ]]; then
        if git checkout "${FEATURE_REMOTE}/${FEATURE_LOOP_BRANCH}" -- "Loop/Localizable.xcstrings" 2>/dev/null; then
            ((installed++))
            success "Replaced Localizable.xcstrings (direct checkout)"
        else
            warn "Failed to checkout Localizable.xcstrings"
            ((failed++))
        fi
    else
        info "Skipping Localizable.xcstrings (not present on this branch — features use NSLocalizedString fallback)"
    fi

    popd > /dev/null

    success "Installed $installed files"
    if [[ $failed -gt 0 ]]; then
        warn "$failed files failed to install"
    fi
}

# ─── Phase 4b: Install SiteAtlas Body Map Assets ─────────────────────────────

install_body_map_assets() {
    header "Phase 4b: Installing SiteAtlas body map assets"

    pushd Loop > /dev/null

    local assets_base="Loop/DerivedAssetsBase.xcassets"

    # Pull the PNGs from the feature branch into a temp location
    local tmp_front tmp_back
    tmp_front=$(mktemp)
    tmp_back=$(mktemp)

    if git show "${FEATURE_REMOTE}/${FEATURE_LOOP_BRANCH}:Loop/Resources/SiteAtlas/BodyMapFront.png" > "$tmp_front" 2>/dev/null && \
       git show "${FEATURE_REMOTE}/${FEATURE_LOOP_BRANCH}:Loop/Resources/SiteAtlas/BodyMapBack.png" > "$tmp_back" 2>/dev/null; then

        # Create imageset directories
        mkdir -p "$assets_base/BodyMapFront.imageset"
        mkdir -p "$assets_base/BodyMapBack.imageset"

        # Copy PNGs
        cp "$tmp_front" "$assets_base/BodyMapFront.imageset/BodyMapFront.png"
        cp "$tmp_back"  "$assets_base/BodyMapBack.imageset/BodyMapBack.png"

        # Write Contents.json for each
        cat > "$assets_base/BodyMapFront.imageset/Contents.json" << 'IMGEOF'
{
  "images" : [
    {
      "filename" : "BodyMapFront.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
IMGEOF

        cat > "$assets_base/BodyMapBack.imageset/Contents.json" << 'IMGEOF'
{
  "images" : [
    {
      "filename" : "BodyMapBack.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
IMGEOF

        success "Installed BodyMapFront + BodyMapBack imagesets into DerivedAssetsBase.xcassets"
    else
        warn "Could not retrieve body map PNGs from feature branch — SiteAtlas will use fallback icon"
    fi

    rm -f "$tmp_front" "$tmp_back"
    popd > /dev/null
}

# ─── Phase 4d: Override Files (wholesale checkout) ────────────────────────────

override_modified_files() {
    if [[ ${#OVERRIDE_FILES[@]} -eq 0 ]]; then
        return
    fi
    header "Phase 4d: Replacing ${#OVERRIDE_FILES[@]} files wholesale from feat/AllFeatures"

    pushd Loop > /dev/null

    local replaced=0
    local failed=0

    for file in "${OVERRIDE_FILES[@]}"; do
        if git checkout "${FEATURE_REMOTE}/${FEATURE_LOOP_BRANCH}" -- "$file" 2>/dev/null; then
            success "Replaced: $file"
            ((replaced++))
        else
            warn "Could not replace: $file"
            ((failed++))
        fi
    done

    popd > /dev/null

    info "Replaced: $replaced, Failed: $failed"
    if [[ $failed -gt 0 ]]; then
        die "Some override files could not be replaced — install aborted."
    fi
}

# ─── Phase 5: Patch Modified Files ───────────────────────────────────────────

patch_modified_files() {
    header "Phase 5: Patching ${#PATCH_FILES[@]} modified files"

    pushd Loop > /dev/null

    # We need the dev branch as the diff base. feat/AllFeatures was branched from dev,
    # so `git diff dev..feat/AllFeatures` isolates ONLY our feature changes.
    # We fetched dev from our remote in Phase 3, so it's always available —
    # even when the user cloned main (the L&L-compatible path).
    local dev_ref
    dev_ref=$(git rev-parse "${FEATURE_REMOTE}/dev" 2>/dev/null)
    if [[ -z "$dev_ref" ]]; then
        # Fallback to local dev branches
        dev_ref=$(git rev-parse dev 2>/dev/null || git rev-parse origin/dev 2>/dev/null || git rev-parse upstream/dev 2>/dev/null)
    fi
    if [[ -z "$dev_ref" ]]; then
        die "Cannot find dev branch reference. The feature remote fetch may have failed."
    fi

    local patched=0
    local failed=0
    local skipped=0

    for file in "${PATCH_FILES[@]}"; do
        local diff_output
        diff_output=$(git diff "$dev_ref".."${FEATURE_REMOTE}/${FEATURE_LOOP_BRANCH}" -- "$file" 2>/dev/null)

        if [[ -z "$diff_output" ]]; then
            info "No changes for: $file (skipped)"
            ((skipped++))
            continue
        fi

        if echo "$diff_output" | git apply --3way 2>/dev/null; then
            success "Patched: $file"
            ((patched++))
        else
            warn "3-way merge had conflicts for: $file"
            warn "  → Check for conflict markers and resolve manually."
            ((failed++))
        fi
    done

    popd > /dev/null

    info "Patched: $patched, Skipped: $skipped, Conflicts: $failed"
    if [[ $failed -gt 0 ]]; then
        warn "Some files had merge conflicts. Resolve them before building."
    fi
}

# ─── Phase 6: Patch SettingsView.swift (Anchor-Based) ────────────────────────

patch_settings_view() {
    header "Phase 6: Patching SettingsView.swift (anchor-based)"

    local settings_file="Loop/Loop/Views/SettingsView.swift"

    # Use Python for reliable multi-line text insertion
    python3 - "$settings_file" << 'PYTHON_SCRIPT'
import sys

settings_path = sys.argv[1]

with open(settings_path, "r") as f:
    content = f.read()

lines = content.split("\n")

# ─── Anchor 1: Insert feature rows AFTER the Therapy Settings button ───
# We anchor on "Diabetes Treatment" (the Therapy Settings descriptive text) so our
# features appear right after Therapy Settings. If L&L Profiles is installed, it
# inserts before the ForEach — so Profiles ends up BELOW our features.

FEATURE_ROWS = """
            NavigationLink(destination: AutoPresets_SettingsView(dataStoresProvider: viewModel.loopInsightsDataStores)) {
                LargeButton(
                    action: {},
                    includeArrow: false,
                    imageView: AutoPresets_IconView(),
                    label: NSLocalizedString("AutoPresets", comment: "Title text for button to AutoPresets Settings"),
                    descriptiveText: NSLocalizedString("Automate your presets during motion", comment: "Descriptive text for Auto-Apply Presets")
                )
            }

            bolusProSettingsRow

            foodFinderSettingsRow

            loopInsightsSection

            siteAtlasSettingsRow
"""

anchor1 = 'Diabetes Treatment'
anchor1_idx = None
for i, line in enumerate(lines):
    if anchor1 in line:
        anchor1_idx = i
        break

if anchor1_idx is None:
    print(f"ERROR: Anchor 1 not found: {anchor1}", file=sys.stderr)
    sys.exit(1)

# Insert the feature rows AFTER the Therapy Settings descriptive text line
feature_lines = FEATURE_ROWS.rstrip("\n").split("\n")
insert_at = anchor1_idx + 2  # after the NavigationLink closing brace (line after "Diabetes Treatment")
for j, fl in enumerate(feature_lines):
    lines.insert(insert_at + j, fl)
print(f"  Inserted {len(feature_lines)} lines after Therapy Settings (line {anchor1_idx + 1})")

# ─── Anchor 2: Insert computed properties BEFORE "private var cgmChoices:" ───

COMPUTED_PROPS = """
    // BolusPro — single settings insertion point
    private var bolusProSettingsRow: some View {
        NavigationLink(destination: BolusPro_SettingsView()) {
            LargeButton(action: {},
                        includeArrow: false,
                        imageView: Image(systemName: "drop.halffull")
                            .foregroundColor(Color(red: 230/255, green: 188/255, blue: 60/255))
                            .font(.system(size: 36)),
                        label: NSLocalizedString("BolusPro", comment: "Title text for button to BolusPro Settings"),
                        descriptiveText: NSLocalizedString("Protein & fat-aware bolusing for long absorption meals", comment: "Descriptive text for BolusPro Settings"))
        }
    }

    // FoodFinder — single settings insertion point
    private var foodFinderSettingsRow: some View {
        NavigationLink(destination: AISettingsView()) {
            LargeButton(action: {},
                        includeArrow: false,
                        imageView: Image(systemName: "fork.knife.circle.fill")
                            .foregroundColor(Color(red: 107/255, green: 47/255, blue: 160/255))
                            .font(.system(size: 36)),
                        label: NSLocalizedString("FoodFinder", comment: "Title text for button to FoodFinder Settings"),
                        descriptiveText: NSLocalizedString("AI-powered & barcode food analysis", comment: "Descriptive text for FoodFinder Settings"))
        }
    }

    private var loopInsightsSection: some View {
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
    }

    private var siteAtlasSettingsRow: some View {
        NavigationLink(destination: SiteAtlas_SettingsView()) {
            LargeButton(action: {},
                        includeArrow: false,
                        imageView: Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(Color(red: 230/255, green: 126/255, blue: 34/255))
                            .font(.system(size: 36)),
                        label: NSLocalizedString("Site Atlas", comment: "Title text for button to Site Atlas Settings"),
                        descriptiveText: NSLocalizedString("Track pump and sensor site rotation", comment: "Descriptive text for Site Atlas"))
        }
    }

"""

anchor2 = "private var cgmChoices:"
anchor2_idx = None
# Re-scan from scratch since lines array was modified
for i, line in enumerate(lines):
    if anchor2 in line:
        anchor2_idx = i
        break

if anchor2_idx is None:
    print(f"ERROR: Anchor 2 not found: {anchor2}", file=sys.stderr)
    sys.exit(1)

prop_lines = COMPUTED_PROPS.rstrip("\n").split("\n")
for j, pl in enumerate(prop_lines):
    lines.insert(anchor2_idx + j, pl)
print(f"  Inserted {len(prop_lines)} lines before cgmChoices anchor (line {anchor2_idx + 1})")

# Write back
with open(settings_path, "w") as f:
    f.write("\n".join(lines))

print("  SettingsView.swift patched successfully.")
PYTHON_SCRIPT

    if [[ $? -eq 0 ]]; then
        success "SettingsView.swift patched with anchor-based insertion"
    else
        error "Failed to patch SettingsView.swift"
        return 1
    fi
}

# ─── Phase 6c: Patch BolusEntryViewModel.swift (Anchor-Based) ────────────────
#
# L&L Customizations modify the BolusEntryViewModelDelegate protocol signature
# in this file (Result<DoseEntry, any Error> instead of Error?). Wholesale
# replacement clobbers that change; 3-way merge can fail on context drift.
# Anchor-based insertion adds BolusPro additions surgically while leaving the
# protocol declaration and any L&L modifications intact.

patch_bolus_entry_viewmodel() {
    header "Phase 6c: Patching BolusEntryViewModel.swift (anchor-based, BolusPro)"

    local target_file="Loop/Loop/View Models/BolusEntryViewModel.swift"

    if [[ ! -f "$target_file" ]]; then
        warn "BolusEntryViewModel.swift not found — skipping BolusPro patch"
        return
    fi

    python3 - "$target_file" << 'PYTHON_SCRIPT'
import sys

path = sys.argv[1]
with open(path, "r") as f:
    content = f.read()

if "bolusProSecondaryEntry" in content and "bolusProAnalyticsSnapshot" in content:
    print("  Already patched — skipping.")
    sys.exit(0)

lines = content.split("\n")

# ─── Anchor 1: Add the two BolusPro properties after selectedCarbAbsorptionTimeEmoji ───
PROPS_BLOCK = """
    /// BolusPro — optional secondary FPU carb entry, set by
    /// `CarbEntryViewModel.setBolusViewModel()` when the user has the
    /// per-entry toggle on and macros that yield a non-trivial bonus.
    /// Saved alongside the primary in `saveAndDeliver()`.
    var bolusProSecondaryEntry: NewCarbEntry?

    /// BolusPro — analytics snapshot fired to DataLayer + LoopInsights
    /// after the primary entry persists, regardless of whether the
    /// per-entry toggle was on. Populated by CarbEntryViewModel.
    var bolusProAnalyticsSnapshot: BolusProAnalyticsSnapshot?
"""

anchor1 = "let selectedCarbAbsorptionTimeEmoji: String?"
anchor1_idx = None
for i, line in enumerate(lines):
    if anchor1 in line:
        anchor1_idx = i
        break

if anchor1_idx is None:
    print(f"ERROR: Anchor 1 not found: {anchor1}", file=sys.stderr)
    sys.exit(1)

prop_lines = PROPS_BLOCK.rstrip("\n").split("\n")
for j, pl in enumerate(prop_lines):
    lines.insert(anchor1_idx + 1 + j, pl)
print(f"  Inserted {len(prop_lines)} property lines after selectedCarbAbsorptionTimeEmoji (line {anchor1_idx + 1})")

# ─── Anchor 2: Add BolusPro save logic after the primary saveCarbEntry call ───
SAVE_BLOCK = """
                // BolusPro — save the optional secondary FPU entry alongside
                // the primary. Failure here doesn't roll back the primary
                // (the user already committed to that bolus); we just log.
                if let secondary = bolusProSecondaryEntry {
                    if let storedSecondary = await saveCarbEntry(secondary, replacingEntry: nil) {
                        self.analyticsServicesManager?.didAddCarbs(source: "BolusPro", amount: storedSecondary.quantity.doubleValue(for: .gram()))
                    } else {
                        log.error("BolusPro secondary entry save failed — primary already saved.")
                    }
                }

                // BolusPro — fire analytics + BehaviorInsights notification
                // even when per-entry toggle was off, so we capture
                // adoption vs. non-adoption population data.
                if let snapshot = bolusProAnalyticsSnapshot {
                    BolusPro_DataLayerHook.recordSavedEntry(snapshot)
                }
"""

anchor2 = 'self.analyticsServicesManager?.didAddCarbs(source: "Phone"'
anchor2_idx = None
for i, line in enumerate(lines):
    if anchor2 in line:
        anchor2_idx = i
        break

if anchor2_idx is None:
    print(f"ERROR: Anchor 2 not found: {anchor2}", file=sys.stderr)
    sys.exit(1)

save_lines = SAVE_BLOCK.rstrip("\n").split("\n")
for j, sl in enumerate(save_lines):
    lines.insert(anchor2_idx + 1 + j, sl)
print(f"  Inserted {len(save_lines)} save-logic lines after didAddCarbs Phone call (line {anchor2_idx + 1})")

with open(path, "w") as f:
    f.write("\n".join(lines))

print("  BolusEntryViewModel.swift patched successfully.")
PYTHON_SCRIPT
}

# ─── Phase 6b: Patch LoopDataManager.swift (Anchor-Based) ────────────────────
#
# L&L Customizations heavily modify LoopDataManager.swift (Negative Insulin Damper,
# function signature changes, etc.), so git apply --3way fails silently.
# Instead, we use anchor-based insertion like SettingsView.swift.

patch_loop_data_manager() {
    header "Phase 6b: Patching LoopDataManager.swift (anchor-based)"

    local ldm_file="Loop/Loop/Managers/LoopDataManager.swift"

    if [[ ! -f "$ldm_file" ]]; then
        die "LoopDataManager.swift not found at: $ldm_file"
    fi

    # Skip if already patched
    if grep -q "AutoPresets_Coordinator" "$ldm_file"; then
        info "LoopDataManager.swift already contains AutoPresets code — skipping."
        return 0
    fi

    python3 - "$ldm_file" << 'PYTHON_SCRIPT'
import sys

ldm_path = sys.argv[1]

with open(ldm_path, "r") as f:
    content = f.read()

lines = content.split("\n")

# ─── Anchor 1: Insert delegate setup after "self.trustedTimeOffset = trustedTimeOffset" ───
# This is in the init method. The delegate line goes right after this assignment,
# before the LiveActivity setup.

DELEGATE_SETUP = """\

        // Set up AutoPresets coordinator delegate
        AutoPresets_Coordinator.shared.delegate = self

        // Initialize SiteAtlas coordinator
        _ = SiteAtlas_Coordinator.shared
"""

anchor1 = "self.trustedTimeOffset = trustedTimeOffset"
anchor1_idx = None
for i, line in enumerate(lines):
    if anchor1 in line:
        anchor1_idx = i
        break

if anchor1_idx is None:
    print(f"ERROR: Anchor not found: {anchor1}", file=sys.stderr)
    sys.exit(1)

delegate_lines = DELEGATE_SETUP.rstrip("\n").split("\n")
insert_at = anchor1_idx + 1
for j, dl in enumerate(delegate_lines):
    lines.insert(insert_at + j, dl)
print(f"  Inserted delegate setup ({len(delegate_lines)} lines) after line {anchor1_idx + 1}")

# ─── Anchor 2: Append AutoPresetsDelegate extension at end of file ───
# We find the very last closing brace of the file and append after it.

DELEGATE_EXTENSION = """
// MARK: - AutoPresets_Delegate

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
        else {
            return
        }

        logger.default("AutoPresets deactivating preset: %{public}@", preset.name)

        mutateSettings { settings in
            settings.scheduleOverride = nil
        }
    }

    func autoPresets(_ coordinator: AutoPresets_Coordinator,
                     shouldCreatePreset preset: TemporaryScheduleOverridePreset) {
        logger.default("AutoPresets creating AI-recommended preset: %{public}@", preset.name)

        mutateSettings { settings in
            settings.overridePresets.append(preset)
        }
    }

    func autoPresetsAvailablePresets(_ coordinator: AutoPresets_Coordinator) -> [TemporaryScheduleOverridePreset] {
        settings.overridePresets
    }

    func autoPresetsCurrentOverride(_ coordinator: AutoPresets_Coordinator) -> TemporaryScheduleOverride? {
        settings.scheduleOverride
    }
}
"""

extension_lines = DELEGATE_EXTENSION.split("\n")
lines.extend(extension_lines)
print(f"  Appended AutoPresets_Delegate extension ({len(extension_lines)} lines) at end of file")

# Write back
with open(ldm_path, "w") as f:
    f.write("\n".join(lines))

print("  LoopDataManager.swift patched successfully.")
PYTHON_SCRIPT

    if [[ $? -eq 0 ]]; then
        success "LoopDataManager.swift patched with AutoPresets delegate"
    else
        error "Failed to patch LoopDataManager.swift"
        return 1
    fi
}

# ─── Phase 7: Update project.pbxproj ─────────────────────────────────────────

update_pbxproj() {
    header "Phase 7: Updating project.pbxproj"

    local pbxproj="Loop/Loop.xcodeproj/project.pbxproj"

    if [[ ! -f "$pbxproj" ]]; then
        die "project.pbxproj not found at: $pbxproj"
    fi

    # Back up pbxproj
    cp "$pbxproj" "${pbxproj}.backup"

    # Find the update script — alongside this script, or in Scripts/, or download it
    local py_script=""
    local script_dir

    # Try 1: alongside this script (normal local run)
    if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" != "bash" ]]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
        if [[ -f "${script_dir}/update_pbxproj.py" ]]; then
            py_script="${script_dir}/update_pbxproj.py"
        fi
    fi

    # Try 2: in Scripts/ relative to cwd (LoopWorkspace root)
    if [[ -z "$py_script" ]] && [[ -f "Scripts/update_pbxproj.py" ]]; then
        py_script="Scripts/update_pbxproj.py"
    fi

    # Try 3: download from GitHub
    if [[ -z "$py_script" ]]; then
        info "Downloading update_pbxproj.py..."
        mkdir -p Scripts
        if curl -fsSL "${FEATURE_WORKSPACE_REPO}/Scripts/update_pbxproj.py" -o Scripts/update_pbxproj.py; then
            py_script="Scripts/update_pbxproj.py"
            success "Downloaded update_pbxproj.py"
        else
            die "Failed to download update_pbxproj.py from GitHub."
        fi
    fi

    if python3 "$py_script" "$pbxproj"; then
        success "project.pbxproj updated"
    else
        error "Failed to update project.pbxproj — restoring backup"
        cp "${pbxproj}.backup" "$pbxproj"
        return 1
    fi

    # Validate
    if plutil -lint "$pbxproj" > /dev/null 2>&1; then
        success "project.pbxproj passes plutil validation"
        rm -f "${pbxproj}.backup"
    else
        error "project.pbxproj failed plutil validation — restoring backup"
        cp "${pbxproj}.backup" "$pbxproj"
        rm -f "${pbxproj}.backup"
        return 1
    fi
}

# ─── Phase 8: Replace App Icon (PowerPack branding) ─────────────────────────

replace_app_icon() {
    header "Phase 8: Installing Loop AI PowerPack icon"

    # Find the source icon — alongside this script, or download it
    local src_icon=""
    local script_dir

    if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" != "bash" ]]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
        if [[ -f "${script_dir}/AppIcon-PowerPack.png" ]]; then
            src_icon="${script_dir}/AppIcon-PowerPack.png"
        fi
    fi

    if [[ -z "$src_icon" ]] && [[ -f "Scripts/AppIcon-PowerPack.png" ]]; then
        src_icon="Scripts/AppIcon-PowerPack.png"
    fi

    if [[ -z "$src_icon" ]]; then
        info "Downloading AppIcon-PowerPack.png..."
        mkdir -p Scripts
        if curl -fsSL "${FEATURE_WORKSPACE_REPO}/Scripts/AppIcon-PowerPack.png" -o Scripts/AppIcon-PowerPack.png; then
            src_icon="Scripts/AppIcon-PowerPack.png"
            success "Downloaded PowerPack icon"
        else
            warn "Could not download PowerPack icon — skipping icon replacement"
            return 0
        fi
    fi

    local replaced=0

    # Replace icons in all asset catalogs that have AppIcon.appiconset
    for iconset_dir in \
        "OverrideAssetsLoop.xcassets/AppIcon.appiconset" \
        "OverrideAssetsWatchApp.xcassets/AppIcon.appiconset" \
        "Loop/Loop/DerivedAssets.xcassets/AppIcon.appiconset" \
        "Loop/Loop/DerivedAssetsBase.xcassets/AppIcon.appiconset" \
        "Loop/WatchApp/DerivedAssets.xcassets/AppIcon.appiconset" \
        "Loop/WatchApp/DerivedAssetsBase.xcassets/AppIcon.appiconset"; do

        if [[ ! -d "$iconset_dir" ]]; then
            continue
        fi

        # Replace every PNG in this icon set with a resized version of the PowerPack icon
        for png in "$iconset_dir"/*.png; do
            [[ -f "$png" ]] || continue
            # Read the current dimensions and resize the source to match
            local w h
            w=$(sips -g pixelWidth "$png" 2>/dev/null | tail -1 | awk '{print $2}')
            h=$(sips -g pixelHeight "$png" 2>/dev/null | tail -1 | awk '{print $2}')
            if [[ -n "$w" ]] && [[ -n "$h" ]] && [[ "$w" -gt 0 ]]; then
                sips -z "$h" "$w" "$src_icon" --out "$png" > /dev/null 2>&1
                ((replaced++))
            fi
        done
    done

    if [[ $replaced -gt 0 ]]; then
        success "Replaced $replaced icon files across all asset catalogs"
    else
        warn "No icon files found to replace"
    fi
}

# ─── Phase 8b: Patch LoopKit (Therapy Help → LoopInsights) ───────────────────

patch_loopkit() {
    header "Phase 8b: Patching LoopKit for therapy help integration"

    local dismiss_file="LoopKit/LoopKitUI/Extensions/Environment+Dismiss.swift"
    local therapy_file="LoopKit/LoopKitUI/Views/Settings Editors/TherapySettingsView.swift"

    if [[ ! -f "$dismiss_file" ]]; then
        warn "Environment+Dismiss.swift not found at: $(pwd)/$dismiss_file"
        warn "Skipping LoopKit patch"
        return
    fi

    if [[ ! -f "$therapy_file" ]]; then
        warn "TherapySettingsView.swift not found at: $(pwd)/$therapy_file"
    fi

    # 1. Add TherapyHelpRegistry to Environment+Dismiss.swift (if not already present)
    if ! grep -q "TherapyHelpRegistry" "$dismiss_file"; then
        cat >> "$dismiss_file" << 'LOOPKIT_EOF'

// MARK: - Therapy Help Registry

/// Static registry so Loop can inject a "Get help" destination without environment propagation.
/// Set `TherapyHelpRegistry.destination` once at app startup; TherapySettingsView reads it directly.
public final class TherapyHelpRegistry {
    public static var destination: AnyView? = nil
}
LOOPKIT_EOF
        success "Added TherapyHelpRegistry to Environment+Dismiss.swift"
    else
        info "TherapyHelpRegistry already present — skipping"
    fi

    # 2. Patch Loop's SettingsView to register therapy help on appear
    #    Anchors on .navigationViewStyle(.stack) which is at the end of the body
    #    The .onAppear fires when SettingsView appears — BEFORE user navigates to TherapySettingsView
    local settings_file="Loop/Loop/Views/SettingsView.swift"
    if [[ -f "$settings_file" ]] && ! grep -q "TherapyHelpRegistry" "$settings_file"; then
        python3 - "$settings_file" << 'PYEOF'
import sys

filepath = sys.argv[1]
with open(filepath, 'r') as f:
    content = f.read()

old_line = '.navigationViewStyle(.stack)'
new_block = old_line + '''
        .onAppear {
            TherapyHelpRegistry.destination = AnyView(LoopInsights_SettingsView(dataStoresProvider: viewModel.loopInsightsDataStores))
        }'''

if old_line in content:
    content = content.replace(old_line, new_block, 1)
    with open(filepath, 'w') as f:
        f.write(content)
    print("OK: Injected TherapyHelpRegistry into SettingsView onAppear")
else:
    print("FAIL: .navigationViewStyle(.stack) not found in SettingsView")
    sys.exit(1)
PYEOF
        if [[ $? -eq 0 ]]; then
            success "Patched SettingsView.swift with therapy help registry"
        else
            warn "Failed to patch SettingsView.swift therapy help"
        fi
    else
        info "SettingsView therapy help already patched — skipping"
    fi

    # 3. Patch TherapySettingsView to use the static registry
    if [[ -f "$therapy_file" ]] && ! grep -q "TherapyHelpRegistry" "$therapy_file"; then
        python3 - "$therapy_file" << 'PYEOF'
import sys

filepath = sys.argv[1]
with open(filepath, 'r') as f:
    content = f.read()

old_support = '''    private var supportSection: some View {
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

new_support = '''    private var supportSection: some View {
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
    }'''

if old_support in content:
    content = content.replace(old_support, new_support)
    with open(filepath, 'w') as f:
        f.write(content)
    print("OK: supportSection replaced with TherapyHelpRegistry check")
else:
    print("FAIL: supportSection pattern not found in file")
    idx = content.find("private var supportSection")
    if idx >= 0:
        print(f"  Found 'supportSection' at offset {idx}")
        print(f"  Context: {repr(content[idx:idx+120])}")
    else:
        print("  'supportSection' not found anywhere in file!")
    sys.exit(1)
PYEOF
        if [[ $? -eq 0 ]]; then
            success "Patched TherapySettingsView.swift for therapy help"
        else
            warn "Failed to patch TherapySettingsView.swift"
        fi
    else
        info "TherapySettingsView already patched or not found — skipping"
    fi
}

# ─── Phase 9: Validate & Cleanup ─────────────────────────────────────────────

validate_installation() {
    header "Phase 9: Validating installation"

    local missing=0

    # Check a representative sample of files
    local check_files=(
        "Loop/Loop/Views/FoodFinder/FoodFinder_EntryPoint.swift"
        "Loop/Loop/Views/LoopInsights/LoopInsights_DashboardView.swift"
        "Loop/Loop/Views/AutoPresets/AutoPresets_SettingsView.swift"
        "Loop/Loop/Managers/AutoPresets/AutoPresets_Coordinator.swift"
        "Loop/Loop/Services/FoodFinder/FoodFinder_AIAnalysis.swift"
        "Loop/Loop/Services/LoopInsights/LoopInsights_DataAggregator.swift"
        "Loop/Loop/Resources/FoodFinder/FoodFinder_FeatureFlags.swift"
        "Loop/Loop/Resources/LoopInsights/LoopInsights_FeatureFlags.swift"
    )

    for f in "${check_files[@]}"; do
        if [[ ! -f "$f" ]]; then
            warn "Missing: $f"
            ((missing++))
        fi
    done

    if [[ $missing -gt 0 ]]; then
        warn "$missing expected files are missing"
    else
        success "All sample files verified"
    fi

    # Verify SettingsView.swift has our insertions
    local settings_file="Loop/Loop/Views/SettingsView.swift"
    if grep -q "foodFinderSettingsRow" "$settings_file"; then
        success "SettingsView.swift contains FoodFinder row"
    else
        warn "SettingsView.swift is missing FoodFinder row"
    fi

    if grep -q "loopInsightsSection" "$settings_file"; then
        success "SettingsView.swift contains LoopInsights section"
    else
        warn "SettingsView.swift is missing LoopInsights section"
    fi

    if grep -q "AutoPresets_SettingsView" "$settings_file"; then
        success "SettingsView.swift contains AutoPresets row"
    else
        warn "SettingsView.swift is missing AutoPresets row"
    fi

    # Write marker file
    echo "installed=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "Loop/${MARKER_FILE}"
    success "Installation marker written"
}

cleanup() {
    header "Cleanup"

    pushd Loop > /dev/null

    # Remove temp remote
    if git remote | grep -q "^${FEATURE_REMOTE}$"; then
        git remote remove "$FEATURE_REMOTE"
        success "Removed temporary remote: $FEATURE_REMOTE"
    fi

    popd > /dev/null

    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  Installation Complete!${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}Next steps:${NC}"
    echo "  1. Open LoopWorkspace.xcworkspace in Xcode"
    echo "  2. Build and run (Cmd+R)"
    echo "  3. In Loop > Settings > Enable PowerPack Features Individually"
    echo "  4. Enter your AI API key in FoodFinder Settings"
    echo ""
    echo -e "  ${BOLD}To uninstall:${NC}"
    echo "  ./Scripts/install_features.sh --rollback"
    echo ""
}

# ─── Rollback ─────────────────────────────────────────────────────────────────

rollback() {
    header "Rolling back feature installation"

    if [[ ! -d "LoopWorkspace.xcworkspace" ]]; then
        die "Must run from LoopWorkspace root directory."
    fi

    pushd Loop > /dev/null

    # 1. Remove all new feature files
    info "Removing new feature files..."
    local removed=0
    for file in "${NEW_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            ((removed++))
        fi
    done
    success "Removed $removed feature files"

    # Clean up empty directories
    local feature_dirs=(
        "Loop/Views/FoodFinder" "Loop/Views/LoopInsights" "Loop/Views/AutoPresets"
        "Loop/Views/BolusPro" "Loop/Views/SiteAtlas" "Loop/Views/DataLayer"
        "Loop/Models/FoodFinder" "Loop/Models/LoopInsights" "Loop/Models/AutoPresets"
        "Loop/Models/BolusPro" "Loop/Models/SiteAtlas" "Loop/Models/DataLayer"
        "Loop/Services/FoodFinder" "Loop/Services/LoopInsights"
        "Loop/Services/AutoPresets" "Loop/Services/BolusPro" "Loop/Services/SiteAtlas" "Loop/Services/DataLayer"
        "Loop/Resources/FoodFinder" "Loop/Resources/LoopInsights/TestData" "Loop/Resources/LoopInsights" "Loop/Resources/AutoPresets"
        "Loop/Resources/BolusPro" "Loop/Resources/DataLayer"
        "Loop/Managers/LoopInsights" "Loop/Managers/AutoPresets" "Loop/Managers/DataLayer"
        "Loop/View Models/FoodFinder" "Loop/View Models/LoopInsights"
        "LoopTests/FoodFinder" "LoopTests/LoopInsights"
        "Documentation/FoodFinder" "Documentation/LoopInsights"
        "Documentation/AutoPresets" "Documentation/BolusPro" "Documentation/SiteAtlas"
        "Documentation/DataLayer" "Documentation/GraphDetailView"
        "Loop/Services" "Loop/Resources"
    )
    for dir in "${feature_dirs[@]}"; do
        if [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
            rmdir "$dir" 2>/dev/null || true
        fi
    done
    success "Cleaned up empty directories"

    # 2. Reset all files to HEAD state (unstages new files, restores modified files)
    info "Resetting all files to HEAD..."
    git reset HEAD -- . 2>/dev/null || true
    git checkout HEAD -- . 2>/dev/null || true
    # Remove any remaining untracked feature files
    git clean -fd -- Loop/Views/FoodFinder Loop/Views/LoopInsights Loop/Views/AutoPresets \
        Loop/Models/FoodFinder Loop/Models/LoopInsights Loop/Models/AutoPresets \
        Loop/Services/FoodFinder Loop/Services/LoopInsights \
        Loop/Resources/FoodFinder Loop/Resources/LoopInsights Loop/Resources/AutoPresets \
        Loop/Managers/LoopInsights Loop/Managers/AutoPresets \
        "Loop/View Models/FoodFinder" "Loop/View Models/LoopInsights" \
        LoopTests/FoodFinder LoopTests/LoopInsights \
        Documentation/FoodFinder Documentation/LoopInsights \
        2>/dev/null || true
    success "Reset all files to HEAD"

    # 3. Remove marker
    rm -f "$MARKER_FILE"

    # 4. Pop stash if one exists from our install
    local stash_list
    stash_list=$(git stash list 2>/dev/null || true)
    if echo "$stash_list" | grep -q "pre-feature-install"; then
        info "Found pre-install stash, restoring..."
        git stash pop 2>/dev/null || warn "Stash pop had conflicts — resolve manually."
        success "Restored pre-install state"
    fi

    # 5. Remove temp remote if still present
    if git remote | grep -q "^${FEATURE_REMOTE}$"; then
        git remote remove "$FEATURE_REMOTE"
    fi

    popd > /dev/null

    echo ""
    echo -e "${GREEN}${BOLD}  Rollback complete. Your Loop is back to its previous state.${NC}"
    echo ""
}

# ─── Install + Uninstall — internal entry points ─────────────────────────────

do_install() {
    validate_environment
    create_backup
    setup_source_remote
    update_omnible
    bump_version
    install_new_files
    install_body_map_assets
    override_modified_files
    patch_modified_files
    patch_settings_view
    patch_bolus_entry_viewmodel
    patch_loop_data_manager
    update_pbxproj
    replace_app_icon
    patch_loopkit
    validate_installation
    cleanup
}

# ─── Splash + dispatch (shown when running in a LoopWorkspace) ───────────────

show_install_splash() {
    clear 2>/dev/null || true
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  Loop (AID) PowerPack — Bundle Install                   ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "  About to install Loop (AID) PowerPack into:"
    echo "    $(pwd)"
    echo
    echo "  This bundle adds these features (each is OFF by default; turn"
    echo "  them on individually in Loop → Settings after building):"
    echo
    echo "    • AutoPresets       — auto-activate overrides on detected motion"
    echo "    • BolusPro          — protein/fat-aware bolusing for high-FPU meals"
    echo "    • FoodFinder        — AI-assisted carb counting (BYO API key)"
    echo "    • LoopInsights      — AI therapy tuning + Behavior Insights"
    echo "    • DataLayer         — local event store with opt-in cloud upload"
    echo "    • GraphDetailView   — long-press home chart for timestamp detail"
    echo "    • SiteAtlas         — body-map tracker for pump/CGM rotation"
    echo
}

show_uninstall_splash() {
    clear 2>/dev/null || true
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  Loop (AID) PowerPack — Uninstall                        ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
    echo "  About to remove every PowerPack feature from:"
    echo "    $(pwd)"
    echo
    echo "  This reverts all PowerPack file additions and modifications to"
    echo "  Loop's source files. Your Loop install and any L&L customizations"
    echo "  applied before PowerPack stay untouched."
    echo
}

# Detect if PowerPack is currently installed (looks for marker file).
is_powerpack_installed() {
    [[ -f "Loop/${MARKER_FILE}" ]]
}

# Run inside a LoopWorkspace: if already installed, offer reinstall / uninstall / quit;
# otherwise show install splash + Enter-to-continue.
in_workspace_dispatch() {
    if is_powerpack_installed; then
        clear 2>/dev/null || true
        echo -e "${BOLD}Loop (AID) PowerPack${NC}"
        echo
        echo "  PowerPack appears to already be installed in this LoopWorkspace."
        echo
        echo -e "    ${BOLD}1${NC}. Reinstall (uninstall first, then install fresh)"
        echo -e "    ${BOLD}2${NC}. Uninstall PowerPack"
        echo -e "    ${BOLD}Q${NC}. Quit"
        echo
        read -r -p "  Choose [1-2 / Q]: " choice
        case "$choice" in
            1) rollback && do_install ;;
            2) show_uninstall_splash
               read -r -p "  Type 'yes' to uninstall: " confirm
               if [[ "$confirm" == "yes" ]]; then
                   rollback
               else
                   echo "  Aborted."
               fi
               ;;
            Q|q|"") exit 0 ;;
            *) warn "Invalid choice"; sleep 1; in_workspace_dispatch ;;
        esac
    else
        show_install_splash
        read -r -p "  Press Enter to install, or Ctrl-C to cancel..."
        echo
        do_install
    fi
}

# ─── Bootstrap — full end-to-end flow when user is not yet in a LoopWorkspace
#
# Wraps Loop & Learn's BuildSelectScript so a single curl-piped command can
# walk the user through: Loop core install → optional L&L customizations →
# PowerPack install → final instructions to build in Xcode.
# ─────────────────────────────────────────────────────────────────────────────

LL_BUILD_SCRIPT_URL="https://raw.githubusercontent.com/loopandlearn/lnl-scripts/main/BuildSelectScript.sh"
BUILD_LOOP_DIR="${HOME}/Downloads/BuildLoop"

in_loopworkspace() { [[ -d "LoopWorkspace.xcworkspace" ]]; }

find_latest_workspace() {
    [[ -d "$BUILD_LOOP_DIR" ]] || return 1
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
    echo "  You're not in a LoopWorkspace folder. Choose your install path:"
    echo
    echo -e "    ${BOLD}1${NC}. Fresh install ${DIM}(recommended for new users)${NC}"
    echo "        → Installs Loop core, optionally applies L&L customizations,"
    echo "          then drops you into PowerPack install."
    echo
    echo -e "    ${BOLD}2${NC}. I already have a LoopWorkspace — show me where to run this"
    echo
    echo -e "    ${BOLD}Q${NC}. Quit"
    echo
}

run_ll_bootstrap() {
    header "Step 1 of 2: Loop core + (optional) L&L customizations"
    echo
    echo "  Launching the Loop & Learn BuildSelectScript."
    echo "  • Choose ${BOLD}Build Loop${NC}, select the ${BOLD}main${NC} branch."
    echo "  • Apply any L&L customizations you want, or skip if you don't want any."
    echo "  • When the L&L script exits, this installer will resume."
    echo
    read -r -p "  Press Enter to launch L&L BuildSelectScript..."
    echo

    /bin/bash -c "$(curl -fsSL "$LL_BUILD_SCRIPT_URL")" || die "L&L BuildSelectScript failed."

    header "Step 2 of 2: PowerPack install"
    local ws
    ws=$(find_latest_workspace) || die "Couldn't find a fresh LoopWorkspace under ${BUILD_LOOP_DIR}. Did the L&L install succeed?"
    cd "$ws" || die "Couldn't cd into $ws"
    success "Found LoopWorkspace: $ws"
    in_workspace_dispatch
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

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    if in_loopworkspace; then
        in_workspace_dispatch
    else
        bootstrap_dispatch
    fi
}

# ─── Entry Point ──────────────────────────────────────────────────────────────

case "${1:-}" in
    --rollback|--uninstall) rollback ;;
    --install|--all|-y)     do_install ;;
    -h|--help)              sed -n '2,25p' "${BASH_SOURCE[0]:-$0}" | sed 's|^# \?||'; exit 0 ;;
    "")                     main ;;
    *)                      echo "Unknown argument: $1" >&2; exit 1 ;;
esac
