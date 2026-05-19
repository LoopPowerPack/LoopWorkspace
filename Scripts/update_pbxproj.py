#!/usr/bin/env python3
"""
update_pbxproj.py — Add or remove Loop (AID) PowerPack files in
                     Loop.xcodeproj/project.pbxproj.

USAGE
  python3 update_pbxproj.py [--features <ids>] [--remove-features <ids>] <pbxproj>

  --features <ids>          Comma-separated feature ids to add (default: all)
  --remove-features <ids>   Comma-separated feature ids to remove

  Feature ids: autopresets, bolus_pro, graph_detail_view, site_atlas,
               food_finder, loop_insights

EXAMPLES
  python3 update_pbxproj.py Loop/Loop.xcodeproj/project.pbxproj
      → adds every PowerPack file (back-compat: same as the old all-features run)

  python3 update_pbxproj.py --features bolus_pro Loop/Loop.xcodeproj/project.pbxproj
      → adds only BolusPro files

  python3 update_pbxproj.py --remove-features bolus_pro Loop/Loop.xcodeproj/project.pbxproj
      → removes only BolusPro file references / build entries

DETERMINISTIC UUIDS
  Each file/group/buildfile gets a stable md5-derived UUID so repeated
  installs and remove → reinstall cycles produce identical pbxproj content.
  This is what makes the per-feature removal code able to find the exact
  entries it added.

GROUP CLEANUP
  Removing a feature deletes its PBXBuildFile, PBXFileReference, group
  children, and PBXSourcesBuildPhase entries. Empty PBXGroup definitions
  are intentionally left in place — they're harmless and reusing them on
  reinstall is faster than recreating.

Idea by Taylor Patterson. Coded by Claude Code.
Copyright © 2026 LoopKit Authors and Taylor Patterson.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from typing import Optional


# ─────────────────────────────────────────────────────────────────────────────
# Feature ids
# ─────────────────────────────────────────────────────────────────────────────

ALL_FEATURE_IDS = (
    "autopresets",
    "bolus_pro",
    "graph_detail_view",
    "site_atlas",
    "food_finder",
    "loop_insights",
)


def make_uuid(name: str) -> str:
    """Generate a deterministic 24-char hex UUID from a name."""
    return hashlib.md5(f"FeatureInstaller_{name}".encode()).hexdigest()[:24].upper()


def fileref_uuid(filename: str) -> str:
    return make_uuid(f"fileref_{filename}")


def buildfile_uuid(filename: str) -> str:
    return make_uuid(f"buildfile_{filename}")


def group_uuid(group_key: str) -> str:
    return make_uuid(f"group_{group_key}")


# ─────────────────────────────────────────────────────────────────────────────
# File manifest
#
# (relative_path_from_Loop/, filename, parent_group_key, feature_id)
# ─────────────────────────────────────────────────────────────────────────────

SOURCE_FILES: list[tuple[str, str, str, str]] = [
    # ── GraphDetailView ──
    ("Managers/GraphDetailViewModel.swift",  "GraphDetailViewModel.swift",  "Managers", "graph_detail_view"),
    ("Views/GraphDetailView.swift",          "GraphDetailView.swift",       "Views",    "graph_detail_view"),

    # ── AutoPresets — Managers ──
    ("Managers/AutoPresets/AutoPresets_ActivityDetectionManager.swift", "AutoPresets_ActivityDetectionManager.swift", "Managers/AutoPresets", "autopresets"),
    ("Managers/AutoPresets/AutoPresets_Coordinator.swift",              "AutoPresets_Coordinator.swift",              "Managers/AutoPresets", "autopresets"),
    ("Managers/AutoPresets/AutoPresets_Delegate.swift",                 "AutoPresets_Delegate.swift",                 "Managers/AutoPresets", "autopresets"),
    ("Managers/AutoPresets/AutoPresets_GeofenceManager.swift",          "AutoPresets_GeofenceManager.swift",          "Managers/AutoPresets", "autopresets"),
    ("Managers/AutoPresets/AutoPresets_CalendarManager.swift",          "AutoPresets_CalendarManager.swift",          "Managers/AutoPresets", "autopresets"),
    ("Managers/AutoPresets/AutoPresets_Logger.swift",                   "AutoPresets_Logger.swift",                   "Managers/AutoPresets", "autopresets"),
    ("Managers/AutoPresets/AutoPresets_Storage.swift",                  "AutoPresets_Storage.swift",                  "Managers/AutoPresets", "autopresets"),

    # ── AutoPresets — Models ──
    ("Models/AutoPresets/AutoPresets_Models.swift",                    "AutoPresets_Models.swift",                  "Models/AutoPresets", "autopresets"),
    ("Models/AutoPresets/AutoPresets_RecommendationModels.swift",      "AutoPresets_RecommendationModels.swift",    "Models/AutoPresets", "autopresets"),

    # ── AutoPresets — Services ──
    ("Services/AutoPresets/AutoPresets_AIAdvisor.swift",               "AutoPresets_AIAdvisor.swift",               "Services/AutoPresets", "autopresets"),

    # ── AutoPresets — Resources ──
    ("Resources/AutoPresets/AutoPresets_FeatureFlags.swift",           "AutoPresets_FeatureFlags.swift",            "Resources/AutoPresets", "autopresets"),

    # ── AutoPresets — Views ──
    ("Views/AutoPresets/AutoPresets_AIRecommendationView.swift",      "AutoPresets_AIRecommendationView.swift",    "Views/AutoPresets", "autopresets"),
    ("Views/AutoPresets/AutoPresets_GeofenceSettingsView.swift",       "AutoPresets_GeofenceSettingsView.swift",    "Views/AutoPresets", "autopresets"),
    ("Views/AutoPresets/AutoPresets_CalendarSettingsView.swift",      "AutoPresets_CalendarSettingsView.swift",    "Views/AutoPresets", "autopresets"),
    ("Views/AutoPresets/AutoPresets_SettingsView.swift",               "AutoPresets_SettingsView.swift",            "Views/AutoPresets", "autopresets"),

    # ── BolusPro ──
    ("Models/BolusPro/BolusPro_Models.swift",                          "BolusPro_Models.swift",                     "Models/BolusPro",     "bolus_pro"),
    ("Resources/BolusPro/BolusPro_FeatureFlags.swift",                 "BolusPro_FeatureFlags.swift",               "Resources/BolusPro",  "bolus_pro"),
    ("Services/BolusPro/BolusPro_FPUCalculator.swift",                 "BolusPro_FPUCalculator.swift",              "Services/BolusPro",   "bolus_pro"),
    ("Services/BolusPro/BolusPro_DataLayerHook.swift",                 "BolusPro_DataLayerHook.swift",              "Services/BolusPro",   "bolus_pro"),
    ("Services/BolusPro/BolusPro_BehaviorAnalyzer.swift",              "BolusPro_BehaviorAnalyzer.swift",           "Services/BolusPro",   "bolus_pro"),
    ("Views/BolusPro/BolusPro_InfoSheet.swift",                        "BolusPro_InfoSheet.swift",                  "Views/BolusPro",      "bolus_pro"),
    ("Views/BolusPro/BolusPro_OnboardingView.swift",                   "BolusPro_OnboardingView.swift",             "Views/BolusPro",      "bolus_pro"),
    ("Views/BolusPro/BolusPro_ManualMacroFields.swift",                "BolusPro_ManualMacroFields.swift",          "Views/BolusPro",      "bolus_pro"),
    ("Views/BolusPro/BolusPro_CarbEntrySection.swift",                 "BolusPro_CarbEntrySection.swift",           "Views/BolusPro",      "bolus_pro"),
    ("Views/BolusPro/BolusPro_SettingsView.swift",                     "BolusPro_SettingsView.swift",               "Views/BolusPro",      "bolus_pro"),

    # ── FoodFinder ──
    ("Models/FoodFinder/FoodFinder_AnalysisRecord.swift",   "FoodFinder_AnalysisRecord.swift",   "Models/FoodFinder",      "food_finder"),
    ("Models/FoodFinder/FoodFinder_InputResults.swift",     "FoodFinder_InputResults.swift",     "Models/FoodFinder",      "food_finder"),
    ("Models/FoodFinder/FoodFinder_Models.swift",           "FoodFinder_Models.swift",           "Models/FoodFinder",      "food_finder"),
    ("Resources/FoodFinder/FoodFinder_FeatureFlags.swift",  "FoodFinder_FeatureFlags.swift",     "Resources/FoodFinder",   "food_finder"),
    ("Services/FoodFinder/FoodFinder_AIAnalysis.swift",     "FoodFinder_AIAnalysis.swift",       "Services/FoodFinder",    "food_finder"),
    ("Services/FoodFinder/FoodFinder_AIProviderConfig.swift","FoodFinder_AIProviderConfig.swift","Services/FoodFinder",    "food_finder"),
    ("Services/FoodFinder/FoodFinder_AIServiceAdapter.swift","FoodFinder_AIServiceAdapter.swift","Services/FoodFinder",    "food_finder"),
    ("Services/FoodFinder/FoodFinder_AIServiceManager.swift","FoodFinder_AIServiceManager.swift","Services/FoodFinder",    "food_finder"),
    ("Services/FoodFinder/FoodFinder_AnalysisHistoryStore.swift","FoodFinder_AnalysisHistoryStore.swift","Services/FoodFinder","food_finder"),
    ("Services/FoodFinder/FoodFinder_CarbTrackingService.swift","FoodFinder_CarbTrackingService.swift","Services/FoodFinder","food_finder"),
    ("Services/FoodFinder/FoodFinder_EmojiProvider.swift",  "FoodFinder_EmojiProvider.swift",    "Services/FoodFinder",    "food_finder"),
    ("Services/FoodFinder/FoodFinder_ImageDownloader.swift","FoodFinder_ImageDownloader.swift",  "Services/FoodFinder",    "food_finder"),
    ("Services/FoodFinder/FoodFinder_ImageStore.swift",     "FoodFinder_ImageStore.swift",       "Services/FoodFinder",    "food_finder"),
    ("Services/FoodFinder/FoodFinder_LocationService.swift","FoodFinder_LocationService.swift",  "Services/FoodFinder",    "food_finder"),
    ("Services/FoodFinder/FoodFinder_OpenFoodFactsService.swift","FoodFinder_OpenFoodFactsService.swift","Services/FoodFinder","food_finder"),
    ("Services/FoodFinder/FoodFinder_ScannerService.swift", "FoodFinder_ScannerService.swift",   "Services/FoodFinder",    "food_finder"),
    ("Services/FoodFinder/FoodFinder_SearchRouter.swift",   "FoodFinder_SearchRouter.swift",     "Services/FoodFinder",    "food_finder"),
    ("Services/FoodFinder/FoodFinder_SecureStorage.swift",  "FoodFinder_SecureStorage.swift",    "Services/FoodFinder",    "food_finder"),
    ("Services/FoodFinder/FoodFinder_VoiceService.swift",   "FoodFinder_VoiceService.swift",     "Services/FoodFinder",    "food_finder"),
    ("View Models/FoodFinder/FoodFinder_SearchViewModel.swift","FoodFinder_SearchViewModel.swift","View Models/FoodFinder","food_finder"),
    ("Views/FoodFinder/FoodFinder_AICameraView.swift",      "FoodFinder_AICameraView.swift",     "Views/FoodFinder",       "food_finder"),
    ("Views/FoodFinder/FoodFinder_CarbTrackingDashboard.swift","FoodFinder_CarbTrackingDashboard.swift","Views/FoodFinder","food_finder"),
    ("Views/FoodFinder/FoodFinder_EntryPoint.swift",        "FoodFinder_EntryPoint.swift",       "Views/FoodFinder",       "food_finder"),
    ("Views/FoodFinder/FoodFinder_FavoritesHelpers.swift",  "FoodFinder_FavoritesHelpers.swift", "Views/FoodFinder",       "food_finder"),
    ("Views/FoodFinder/FoodFinder_ImageCropView.swift",     "FoodFinder_ImageCropView.swift",    "Views/FoodFinder",       "food_finder"),
    ("Views/FoodFinder/FoodFinder_ScannerView.swift",       "FoodFinder_ScannerView.swift",      "Views/FoodFinder",       "food_finder"),
    ("Views/FoodFinder/FoodFinder_SearchBar.swift",         "FoodFinder_SearchBar.swift",        "Views/FoodFinder",       "food_finder"),
    ("Views/FoodFinder/FoodFinder_SearchResultsView.swift", "FoodFinder_SearchResultsView.swift","Views/FoodFinder",       "food_finder"),
    ("Views/FoodFinder/FoodFinder_SettingsView.swift",      "FoodFinder_SettingsView.swift",     "Views/FoodFinder",       "food_finder"),
    ("Views/FoodFinder/FoodFinder_VoiceSearchView.swift",   "FoodFinder_VoiceSearchView.swift",  "Views/FoodFinder",       "food_finder"),

    # ── LoopInsights (includes DataLayer infrastructure) ──
    ("Managers/LoopInsights/LoopInsights_BackgroundMonitor.swift", "LoopInsights_BackgroundMonitor.swift", "Managers/LoopInsights", "loop_insights"),
    ("Managers/LoopInsights/LoopInsights_Coordinator.swift",       "LoopInsights_Coordinator.swift",       "Managers/LoopInsights", "loop_insights"),
    ("Managers/DataLayer/DataLayer_Coordinator.swift",             "DataLayer_Coordinator.swift",          "Managers/DataLayer",    "loop_insights"),
    ("Models/LoopInsights/LoopInsights_Models.swift",              "LoopInsights_Models.swift",            "Models/LoopInsights",   "loop_insights"),
    ("Models/LoopInsights/LoopInsights_MFPModels.swift",           "LoopInsights_MFPModels.swift",         "Models/LoopInsights",   "loop_insights"),
    ("Models/LoopInsights/LoopInsights_Phase5Models.swift",        "LoopInsights_Phase5Models.swift",      "Models/LoopInsights",   "loop_insights"),
    ("Models/LoopInsights/LoopInsights_SuggestionRecord.swift",    "LoopInsights_SuggestionRecord.swift",  "Models/LoopInsights",   "loop_insights"),
    ("Models/LoopInsights/LoopInsights_MealDebriefModels.swift",   "LoopInsights_MealDebriefModels.swift", "Models/LoopInsights",   "loop_insights"),
    ("Models/DataLayer/DataLayer_EventModels.swift",               "DataLayer_EventModels.swift",          "Models/DataLayer",      "loop_insights"),
    ("Models/DataLayer/DataLayer_ConsentModels.swift",             "DataLayer_ConsentModels.swift",        "Models/DataLayer",      "loop_insights"),
    ("Resources/LoopInsights/LoopInsights_FeatureFlags.swift",     "LoopInsights_FeatureFlags.swift",      "Resources/LoopInsights","loop_insights"),
    ("Resources/DataLayer/DataLayer_FeatureFlags.swift",           "DataLayer_FeatureFlags.swift",         "Resources/DataLayer",   "loop_insights"),
    ("Services/LoopInsights/LoopInsights_AdvancedAnalyzers.swift", "LoopInsights_AdvancedAnalyzers.swift", "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_AIAnalysis.swift",        "LoopInsights_AIAnalysis.swift",        "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_AIServiceAdapter.swift",  "LoopInsights_AIServiceAdapter.swift",  "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_AlcoholTracker.swift",    "LoopInsights_AlcoholTracker.swift",    "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_BackfillDetector.swift",  "LoopInsights_BackfillDetector.swift",  "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_BehaviorInsightsAnalyzer.swift","LoopInsights_BehaviorInsightsAnalyzer.swift","Services/LoopInsights","loop_insights"),
    ("Services/LoopInsights/LoopInsights_CaffeineTracker.swift",   "LoopInsights_CaffeineTracker.swift",   "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_CaregiverDigestService.swift","LoopInsights_CaregiverDigestService.swift","Services/LoopInsights","loop_insights"),
    ("Services/LoopInsights/LoopInsights_ChatHistoryStore.swift",  "LoopInsights_ChatHistoryStore.swift",  "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_DataAggregator.swift",    "LoopInsights_DataAggregator.swift",    "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_FoodResponseAnalyzer.swift","LoopInsights_FoodResponseAnalyzer.swift","Services/LoopInsights","loop_insights"),
    ("Services/LoopInsights/LoopInsights_GlucoseUnitContext.swift","LoopInsights_GlucoseUnitContext.swift","Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_GoalStore.swift",         "LoopInsights_GoalStore.swift",         "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_HealthKitManager.swift",  "LoopInsights_HealthKitManager.swift",  "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_NightscoutImporter.swift","LoopInsights_NightscoutImporter.swift","Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_ReportGenerator.swift",   "LoopInsights_ReportGenerator.swift",   "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_SecureStorage.swift",     "LoopInsights_SecureStorage.swift",     "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_SuggestionStore.swift",   "LoopInsights_SuggestionStore.swift",   "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_TestDataProvider.swift",  "LoopInsights_TestDataProvider.swift",  "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_VoiceService.swift",      "LoopInsights_VoiceService.swift",      "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_MealDebriefService.swift","LoopInsights_MealDebriefService.swift","Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_MFPImporter.swift",       "LoopInsights_MFPImporter.swift",       "Services/LoopInsights", "loop_insights"),
    ("Services/LoopInsights/LoopInsights_PreMealAdvisorService.swift","LoopInsights_PreMealAdvisorService.swift","Services/LoopInsights","loop_insights"),
    ("Services/DataLayer/DataLayer_SecureStorage.swift",           "DataLayer_SecureStorage.swift",        "Services/DataLayer",    "loop_insights"),
    ("Services/DataLayer/DataLayer_ConsentManager.swift",          "DataLayer_ConsentManager.swift",       "Services/DataLayer",    "loop_insights"),
    ("Services/DataLayer/DataLayer_EventStore.swift",              "DataLayer_EventStore.swift",           "Services/DataLayer",    "loop_insights"),
    ("Services/DataLayer/DataLayer_EventCollector.swift",          "DataLayer_EventCollector.swift",       "Services/DataLayer",    "loop_insights"),
    ("Services/DataLayer/DataLayer_SyncService.swift",             "DataLayer_SyncService.swift",          "Services/DataLayer",    "loop_insights"),
    ("Services/DataLayer/DataLayer_ReportGenerator.swift",         "DataLayer_ReportGenerator.swift",      "Services/DataLayer",    "loop_insights"),
    ("Services/DataLayer/DataLayer_ProviderProtocol.swift",        "DataLayer_ProviderProtocol.swift",     "Services/DataLayer",    "loop_insights"),
    ("View Models/LoopInsights/LoopInsights_ChatViewModel.swift",  "LoopInsights_ChatViewModel.swift",     "View Models/LoopInsights","loop_insights"),
    ("View Models/LoopInsights/LoopInsights_DashboardViewModel.swift","LoopInsights_DashboardViewModel.swift","View Models/LoopInsights","loop_insights"),
    ("View Models/LoopInsights/LoopInsights_MealInsightsViewModel.swift","LoopInsights_MealInsightsViewModel.swift","View Models/LoopInsights","loop_insights"),
    ("Views/LoopInsights/LoopInsights_AGPChartView.swift",         "LoopInsights_AGPChartView.swift",      "Views/LoopInsights",    "loop_insights"),
    ("Views/LoopInsights/LoopInsights_AlcoholLogView.swift",       "LoopInsights_AlcoholLogView.swift",    "Views/LoopInsights",    "loop_insights"),
    ("Views/LoopInsights/LoopInsights_BehaviorInsightsView.swift", "LoopInsights_BehaviorInsightsView.swift","Views/LoopInsights",  "loop_insights"),
    ("Views/LoopInsights/LoopInsights_CaregiverDigestView.swift",  "LoopInsights_CaregiverDigestView.swift","Views/LoopInsights",   "loop_insights"),
    ("Views/LoopInsights/LoopInsights_EndoReportView.swift",       "LoopInsights_EndoReportView.swift",    "Views/LoopInsights",    "loop_insights"),
    ("Views/LoopInsights/LoopInsights_ChatHistoryView.swift",      "LoopInsights_ChatHistoryView.swift",   "Views/LoopInsights",    "loop_insights"),
    ("Views/LoopInsights/LoopInsights_CaffeineLogView.swift",      "LoopInsights_CaffeineLogView.swift",   "Views/LoopInsights",    "loop_insights"),
    ("Views/LoopInsights/LoopInsights_ChatView.swift",             "LoopInsights_ChatView.swift",          "Views/LoopInsights",    "loop_insights"),
    ("Views/LoopInsights/LoopInsights_DashboardView.swift",        "LoopInsights_DashboardView.swift",     "Views/LoopInsights",    "loop_insights"),
    ("Views/LoopInsights/LoopInsights_GoalsView.swift",            "LoopInsights_GoalsView.swift",         "Views/LoopInsights",    "loop_insights"),
    ("Views/LoopInsights/LoopInsights_MealInsightsView.swift",     "LoopInsights_MealInsightsView.swift",  "Views/LoopInsights",    "loop_insights"),
    ("Views/LoopInsights/LoopInsights_MonitorSettingsView.swift",  "LoopInsights_MonitorSettingsView.swift","Views/LoopInsights",   "loop_insights"),
    ("Views/LoopInsights/LoopInsights_SettingsView.swift",         "LoopInsights_SettingsView.swift",      "Views/LoopInsights",    "loop_insights"),
    ("Views/LoopInsights/LoopInsights_SuggestionDetailView.swift", "LoopInsights_SuggestionDetailView.swift","Views/LoopInsights",  "loop_insights"),
    ("Views/LoopInsights/LoopInsights_SuggestionHistoryView.swift","LoopInsights_SuggestionHistoryView.swift","Views/LoopInsights", "loop_insights"),
    ("Views/LoopInsights/LoopInsights_TrendsInsightsView.swift",   "LoopInsights_TrendsInsightsView.swift","Views/LoopInsights",    "loop_insights"),
    ("Views/LoopInsights/LoopInsights_MealDebriefCard.swift",      "LoopInsights_MealDebriefCard.swift",   "Views/LoopInsights",    "loop_insights"),
    ("Views/LoopInsights/LoopInsights_PreMealAdvisorCard.swift",   "LoopInsights_PreMealAdvisorCard.swift","Views/LoopInsights",    "loop_insights"),
    ("Views/DataLayer/DataLayer_ConsentView.swift",                "DataLayer_ConsentView.swift",          "Views/DataLayer",       "loop_insights"),
    ("Views/DataLayer/DataLayer_DashboardView.swift",              "DataLayer_DashboardView.swift",        "Views/DataLayer",       "loop_insights"),

    # ── SiteAtlas ──
    ("Models/SiteAtlas/SiteAtlas_Models.swift",                    "SiteAtlas_Models.swift",                  "Models/SiteAtlas",  "site_atlas"),
    ("Services/SiteAtlas/SiteAtlas_Coordinator.swift",             "SiteAtlas_Coordinator.swift",             "Services/SiteAtlas","site_atlas"),
    ("Services/SiteAtlas/SiteAtlas_FeatureFlags.swift",            "SiteAtlas_FeatureFlags.swift",            "Services/SiteAtlas","site_atlas"),
    ("Services/SiteAtlas/SiteAtlas_Storage.swift",                 "SiteAtlas_Storage.swift",                 "Services/SiteAtlas","site_atlas"),
    ("Views/SiteAtlas/SiteAtlas_BodyMapView.swift",                "SiteAtlas_BodyMapView.swift",             "Views/SiteAtlas",   "site_atlas"),
    ("Views/SiteAtlas/SiteAtlas_SettingsView.swift",               "SiteAtlas_SettingsView.swift",            "Views/SiteAtlas",   "site_atlas"),
    ("Views/SiteAtlas/SiteAtlas_SiteSelectionSheet.swift",         "SiteAtlas_SiteSelectionSheet.swift",      "Views/SiteAtlas",   "site_atlas"),
]

TEST_FILES: list[tuple[str, str, str, str]] = [
    ("FoodFinder/FoodFinder_BarcodeScannerTests.swift",      "FoodFinder_BarcodeScannerTests.swift",      "LoopTests/FoodFinder",   "food_finder"),
    ("FoodFinder/FoodFinder_OpenFoodFactsTests.swift",       "FoodFinder_OpenFoodFactsTests.swift",       "LoopTests/FoodFinder",   "food_finder"),
    ("FoodFinder/FoodFinder_VoiceSearchTests.swift",         "FoodFinder_VoiceSearchTests.swift",         "LoopTests/FoodFinder",   "food_finder"),
    ("LoopInsights/LoopInsights_DataAggregatorTests.swift",  "LoopInsights_DataAggregatorTests.swift",    "LoopTests/LoopInsights", "loop_insights"),
    ("LoopInsights/LoopInsights_ModelsTests.swift",          "LoopInsights_ModelsTests.swift",            "LoopTests/LoopInsights", "loop_insights"),
    ("LoopInsights/LoopInsights_SuggestionStoreTests.swift", "LoopInsights_SuggestionStoreTests.swift",   "LoopTests/LoopInsights", "loop_insights"),
]

# (group_key, display_name, path, parent_group_key, owning_feature_or_None)
# owning_feature is set for feature-specific subgroups; shared parent groups
# (Services, Resources) have None. None-owned groups are never removed on
# uninstall — they persist for any other feature's use.

SUBGROUPS: list[tuple[str, str, str, str, Optional[str]]] = [
    # Generic top-level groups under Loop (created on first use, never removed)
    ("Services",                "Services",      "Services",      "Loop",       None),
    ("Resources",               "Resources",     "Resources",     "Loop",       None),

    # AutoPresets feature subgroups
    ("Managers/AutoPresets",    "AutoPresets",   "AutoPresets",   "Managers",   "autopresets"),
    ("Models/AutoPresets",      "AutoPresets",   "AutoPresets",   "Models",     "autopresets"),
    ("Services/AutoPresets",    "AutoPresets",   "AutoPresets",   "Services",   "autopresets"),
    ("Resources/AutoPresets",   "AutoPresets",   "AutoPresets",   "Resources",  "autopresets"),
    ("Views/AutoPresets",       "AutoPresets",   "AutoPresets",   "Views",      "autopresets"),

    # BolusPro feature subgroups
    ("Models/BolusPro",         "BolusPro",      "BolusPro",      "Models",     "bolus_pro"),
    ("Resources/BolusPro",      "BolusPro",      "BolusPro",      "Resources",  "bolus_pro"),
    ("Services/BolusPro",       "BolusPro",      "BolusPro",      "Services",   "bolus_pro"),
    ("Views/BolusPro",          "BolusPro",      "BolusPro",      "Views",      "bolus_pro"),

    # FoodFinder feature subgroups
    ("Models/FoodFinder",       "FoodFinder",    "FoodFinder",    "Models",     "food_finder"),
    ("Resources/FoodFinder",    "FoodFinder",    "FoodFinder",    "Resources",  "food_finder"),
    ("Services/FoodFinder",     "FoodFinder",    "FoodFinder",    "Services",   "food_finder"),
    ("View Models/FoodFinder",  "FoodFinder",    "FoodFinder",    "View Models","food_finder"),
    ("Views/FoodFinder",        "FoodFinder",    "FoodFinder",    "Views",      "food_finder"),
    ("LoopTests/FoodFinder",    "FoodFinder",    "FoodFinder",    "LoopTests",  "food_finder"),

    # LoopInsights feature subgroups (incl. DataLayer)
    ("Managers/LoopInsights",   "LoopInsights",  "LoopInsights",  "Managers",   "loop_insights"),
    ("Managers/DataLayer",      "DataLayer",     "DataLayer",     "Managers",   "loop_insights"),
    ("Models/LoopInsights",     "LoopInsights",  "LoopInsights",  "Models",     "loop_insights"),
    ("Models/DataLayer",        "DataLayer",     "DataLayer",     "Models",     "loop_insights"),
    ("Resources/LoopInsights",  "LoopInsights",  "LoopInsights",  "Resources",  "loop_insights"),
    ("Resources/DataLayer",     "DataLayer",     "DataLayer",     "Resources",  "loop_insights"),
    ("Services/LoopInsights",   "LoopInsights",  "LoopInsights",  "Services",   "loop_insights"),
    ("Services/DataLayer",      "DataLayer",     "DataLayer",     "Services",   "loop_insights"),
    ("View Models/LoopInsights","LoopInsights",  "LoopInsights",  "View Models","loop_insights"),
    ("Views/LoopInsights",      "LoopInsights",  "LoopInsights",  "Views",      "loop_insights"),
    ("Views/DataLayer",         "DataLayer",     "DataLayer",     "Views",      "loop_insights"),
    ("LoopTests/LoopInsights",  "LoopInsights",  "LoopInsights",  "LoopTests",  "loop_insights"),

    # SiteAtlas feature subgroups
    ("Models/SiteAtlas",        "SiteAtlas",     "SiteAtlas",     "Models",     "site_atlas"),
    ("Services/SiteAtlas",      "SiteAtlas",     "SiteAtlas",     "Services",   "site_atlas"),
    ("Views/SiteAtlas",         "SiteAtlas",     "SiteAtlas",     "Views",      "site_atlas"),
]


# ─────────────────────────────────────────────────────────────────────────────
# pbxproj parsing
# ─────────────────────────────────────────────────────────────────────────────

def parse_all_groups(content: str) -> dict[str, dict]:
    """Parse all PBXGroup definitions into a dict of uuid -> {name, path, children_uuids}."""
    section_match = re.search(
        r'/\* Begin PBXGroup section \*/\n(.*?)\n/\* End PBXGroup section \*/',
        content, re.DOTALL,
    )
    if not section_match:
        return {}
    section = section_match.group(1)
    groups: dict[str, dict] = {}
    for m in re.finditer(
        r'^\t\t([A-F0-9]{24})\s*(?:/\*[^\n]*?\*/)?\s*= \{\n(.*?)\n\t\t\};',
        section, re.MULTILINE | re.DOTALL,
    ):
        uuid = m.group(1)
        body = m.group(2)
        if "isa = PBXGroup" not in body:
            continue
        path_m = re.search(r'path = "(.*?)";|path = ([^;"\s]+);', body)
        name_m = re.search(r'name = "(.*?)";|name = ([^;"\s]+);', body)
        path_val = (path_m.group(1) or path_m.group(2)) if path_m else None
        name_val = (name_m.group(1) or name_m.group(2)) if name_m else None
        display = name_val or path_val or "unknown"
        children = []
        children_m = re.search(r'children = \(\n(.*?)\n\t\t\t\);', body, re.DOTALL)
        if children_m:
            for c in re.finditer(r'([A-F0-9]{24})', children_m.group(1)):
                children.append(c.group(1))
        groups[uuid] = {"name": display, "path": path_val, "children": children}
    return groups


def find_groups_by_hierarchy(content: str) -> dict[str, str]:
    """Walk PBXProject → mainGroup → Loop. Returns {logical_name: uuid}."""
    all_groups = parse_all_groups(content)
    main_group_match = re.search(r'mainGroup = ([A-F0-9]{24})', content)
    if not main_group_match:
        return {}
    main_group_uuid = main_group_match.group(1)
    main_group = all_groups.get(main_group_uuid, {})
    result: dict[str, str] = {}
    for child_uuid in main_group.get("children", []):
        child = all_groups.get(child_uuid, {})
        child_path = child.get("path")
        child_name = child.get("name")
        if child_path == "Loop" or child_name == "Loop":
            result["Loop"] = child_uuid
        elif child_path == "LoopTests" or child_name == "LoopTests":
            result["LoopTests"] = child_uuid
    loop_uuid = result.get("Loop")
    if loop_uuid and loop_uuid in all_groups:
        for child_uuid in all_groups[loop_uuid]["children"]:
            child = all_groups.get(child_uuid, {})
            display = child.get("name") or child.get("path")
            if display in ("Views", "Models", "View Models", "Managers", "Services", "Resources"):
                result[display] = child_uuid
    return result


def find_main_sources_phase(content: str) -> Optional[str]:
    target_section = re.search(
        r'/\* Begin PBXNativeTarget section \*/\n(.*?)\n/\* End PBXNativeTarget section \*/',
        content, re.DOTALL,
    )
    if not target_section:
        return None
    for m in re.finditer(
        r'([A-F0-9]{24}) /\* (Loop[^*]*?)\*/ = \{(.*?)\n\t\t\};',
        target_section.group(1), re.DOTALL,
    ):
        target_name = m.group(2).strip()
        if target_name == "Loop":
            phases_match = re.search(r'buildPhases = \(\n(.*?)\n\t\t\t\);', m.group(3), re.DOTALL)
            if phases_match:
                sources_match = re.search(r'([A-F0-9]{24}) /\*[^\n]*?Sources[^\n]*?\*/', phases_match.group(1))
                if sources_match:
                    return sources_match.group(1)
    return None


def find_test_sources_phase(content: str) -> Optional[str]:
    target_section = re.search(
        r'/\* Begin PBXNativeTarget section \*/\n(.*?)\n/\* End PBXNativeTarget section \*/',
        content, re.DOTALL,
    )
    if not target_section:
        return None
    for m in re.finditer(
        r'([A-F0-9]{24}) /\* (LoopTests[^*]*?)\*/ = \{(.*?)\n\t\t\};',
        target_section.group(1), re.DOTALL,
    ):
        target_name = m.group(2).strip()
        if target_name == "LoopTests":
            phases_match = re.search(r'buildPhases = \(\n(.*?)\n\t\t\t\);', m.group(3), re.DOTALL)
            if phases_match:
                sources_match = re.search(r'([A-F0-9]{24}) /\*[^\n]*?Sources[^\n]*?\*/', phases_match.group(1))
                if sources_match:
                    return sources_match.group(1)
    return None


# ─────────────────────────────────────────────────────────────────────────────
# pbxproj mutation: ADD
# ─────────────────────────────────────────────────────────────────────────────

def _section_text(content: str, section_name: str) -> str:
    """Return the body of `/* Begin <section_name> section */ ... /* End <section_name> section */`,
    or "" if the section isn't present."""
    m = re.search(
        rf'/\* Begin {section_name} section \*/(.*?)/\* End {section_name} section \*/',
        content, re.DOTALL,
    )
    return m.group(1) if m else ""


def add_child_to_group(content: str, parent_uuid: str, child_uuid: str, child_name: str) -> str:
    new_child = f"\t\t\t\t{child_uuid} /* {child_name} */,"
    pattern = (
        f"({parent_uuid} /\\*[^\\n]*?\\*/ = \\{{\n"
        f"\\t\\t\\tisa = PBXGroup;\n"
        f"\\t\\t\\tchildren = \\(\n)"
        f"(.*?)"
        f"(\\n\\t\\t\\t\\);)"
    )
    match = re.search(pattern, content, re.DOTALL)
    if match:
        if child_uuid in match.group(2):
            return content  # already present
        content = content[:match.start()] + f"{match.group(1)}{match.group(2)}\n{new_child}{match.group(3)}" + content[match.end():]
    else:
        print(f"  WARNING: could not find PBXGroup {parent_uuid} to add child {child_name}", file=sys.stderr)
    return content


def add_to_build_phase(content: str, phase_uuid: str, entries_block: str) -> str:
    pattern = (
        f"({phase_uuid} /\\*[^\\n]*?\\*/ = \\{{\n"
        f"\\t\\t\\tisa = PBXSourcesBuildPhase;\n"
        f"\\t\\t\\tbuildActionMask = \\d+;\n"
        f"\\t\\t\\tfiles = \\(\n)"
        f"(.*?)"
        f"(\\n\\t\\t\\t\\);\\n\\t\\t\\trunOnlyForDeploymentPostprocessing)"
    )
    match = re.search(pattern, content, re.DOTALL)
    if match:
        content = content[:match.start()] + f"{match.group(1)}{match.group(2)}\n{entries_block}{match.group(3)}" + content[match.end():]
    else:
        print(f"  WARNING: could not find PBXSourcesBuildPhase {phase_uuid} to add entries", file=sys.stderr)
    return content


def build_group_def(uuid: str, name: str, path: str, child_entries: list[tuple[str, str]]) -> str:
    children_lines = [f"\t\t\t\t{cuuid} /* {cname} */," for cuuid, cname in child_entries]
    return (
        f"\t\t{uuid} /* {name} */ = {{\n"
        f"\t\t\tisa = PBXGroup;\n"
        f"\t\t\tchildren = (\n"
        f"{chr(10).join(children_lines)}\n"
        f"\t\t\t);\n"
        f"\t\t\tpath = {path};\n"
        f"\t\t\tsourceTree = \"<group>\";\n"
        f"\t\t}};"
    )


def add_features(content: str, feature_ids: set[str]) -> str:
    print(f"  Adding features: {sorted(feature_ids)}")
    known = find_groups_by_hierarchy(content)
    main_sources = find_main_sources_phase(content)
    test_sources = find_test_sources_phase(content)

    if main_sources is None:
        print("  WARNING: could not locate PBXSourcesBuildPhase for Loop target — source files won't be added to the build", file=sys.stderr)
    if test_sources is None and any(t[3] in feature_ids for t in TEST_FILES):
        print("  WARNING: could not locate PBXSourcesBuildPhase for LoopTests target — test files won't be added", file=sys.stderr)

    # Filter manifests to selected features.
    src = [t for t in SOURCE_FILES if t[3] in feature_ids]
    tst = [t for t in TEST_FILES if t[3] in feature_ids]
    # SUBGROUPS we need: shared parents (None-owned) plus this feature's subgroups.
    sub = [t for t in SUBGROUPS if t[4] is None or t[4] in feature_ids]

    # Cache existing section bodies so duplicate-detection is scoped correctly.
    # Critical: a FileRef UUID also appears INSIDE its BuildFile entry's
    # `fileRef = <fr>` field, so a naive `if fr not in content` check would
    # produce false positives after step 1 inserts BuildFile entries and skip
    # the corresponding PBXFileReference entry — leaving Xcode unable to
    # resolve the type. Scope each duplicate check to the right section.
    buildfile_block = _section_text(content, "PBXBuildFile")
    fileref_block   = _section_text(content, "PBXFileReference")

    # ── 1. PBXBuildFile entries
    build_entries = []
    skipped_bf = 0
    for path, name, _, _ in src + tst:
        bf = buildfile_uuid(name)
        fr = fileref_uuid(name)
        entry = f"\t\t{bf} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};"
        if bf in buildfile_block:
            skipped_bf += 1
            continue
        build_entries.append(entry)
    if build_entries:
        content = content.replace(
            "/* End PBXBuildFile section */",
            "\n".join(build_entries) + "\n/* End PBXBuildFile section */",
        )
    print(f"    PBXBuildFile entries: added={len(build_entries)} skipped={skipped_bf}")

    # ── 2. PBXFileReference entries
    ref_entries = []
    skipped_fr = 0
    for path, name, _, _ in src + tst:
        fr = fileref_uuid(name)
        entry = (
            f"\t\t{fr} /* {name} */ = "
            f"{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
            f"path = {name}; sourceTree = \"<group>\"; }};"
        )
        if fr in fileref_block:
            skipped_fr += 1
            continue
        ref_entries.append(entry)
    if ref_entries:
        content = content.replace(
            "/* End PBXFileReference section */",
            "\n".join(ref_entries) + "\n/* End PBXFileReference section */",
        )
    print(f"    PBXFileReference entries: added={len(ref_entries)} skipped={skipped_fr}")

    # ── 3. Build child lists per subgroup
    group_children: dict[str, list[tuple[str, str]]] = {gkey: [] for gkey, _, _, _, _ in sub}
    for path, name, gkey, _ in src + tst:
        group_children.setdefault(gkey, []).append((fileref_uuid(name), name))
    for gkey, gname, _, gparent, _ in sub:
        group_children.setdefault(gparent, []).append((group_uuid(gkey), gname))

    # ── 4. Create PBXGroup defs for new subgroups
    new_group_defs = []
    for gkey, gname, gpath, gparent, _ in sub:
        if gkey in known:
            continue
        gu = group_uuid(gkey)
        # Don't recreate if the group def already exists from a prior install
        if f"{gu} /* {gname} */ = " in content:
            continue
        children = group_children.get(gkey, [])
        new_group_defs.append(build_group_def(gu, gname, gpath, children))
    if new_group_defs:
        content = content.replace(
            "/* End PBXGroup section */",
            "\n".join(new_group_defs) + "\n/* End PBXGroup section */",
        )

    # ── 5. Link new subgroups into existing parents
    group_uuids = {gkey: known.get(gkey, group_uuid(gkey)) for gkey, _, _, _, _ in sub}
    for name, uuid in known.items():
        group_uuids.setdefault(name, uuid)
    for gkey, gname, _, gparent, _ in sub:
        parent_uuid = group_uuids.get(gparent)
        child_uuid = group_uuids[gkey]
        if parent_uuid is None or gparent not in known:
            continue
        content = add_child_to_group(content, parent_uuid, child_uuid, gname)

    # ── 5b. Add files directly to existing parent groups (e.g. GraphDetailViewModel under Managers)
    subgroup_keys = {gkey for gkey, _, _, _, _ in sub}
    for path, name, gkey, _ in src:
        if gkey not in subgroup_keys and gkey in known:
            content = add_child_to_group(content, known[gkey], fileref_uuid(name), name)

    # ── 6. Add files to PBXSourcesBuildPhase
    if main_sources and src:
        main_entries = []
        for _, name, _, _ in src:
            bf = buildfile_uuid(name)
            line = f"\t\t\t\t{bf} /* {name} in Sources */,"
            if line not in content:
                main_entries.append(line)
        if main_entries:
            content = add_to_build_phase(content, main_sources, "\n".join(main_entries))

    if test_sources and tst:
        test_entries = []
        for _, name, _, _ in tst:
            bf = buildfile_uuid(name)
            line = f"\t\t\t\t{bf} /* {name} in Sources */,"
            if line not in content:
                test_entries.append(line)
        if test_entries:
            content = add_to_build_phase(content, test_sources, "\n".join(test_entries))

    print(f"    Added {len(src)} source files, {len(tst)} test files, {len(new_group_defs)} new groups")
    return content


# ─────────────────────────────────────────────────────────────────────────────
# pbxproj mutation: REMOVE
# ─────────────────────────────────────────────────────────────────────────────

def remove_uuid_lines(content: str, uuid: str) -> str:
    """Remove every line that contains the given UUID. Used to scrub:
       - PBXBuildFile entries (whole one-line definition)
       - PBXFileReference entries (whole one-line definition)
       - Children references in PBXGroup
       - File entries in PBXSourcesBuildPhase
    """
    new_lines = []
    for line in content.split("\n"):
        if uuid in line:
            continue
        new_lines.append(line)
    return "\n".join(new_lines)


def remove_features(content: str, feature_ids: set[str]) -> str:
    print(f"  Removing features: {sorted(feature_ids)}")
    src = [t for t in SOURCE_FILES if t[3] in feature_ids]
    tst = [t for t in TEST_FILES if t[3] in feature_ids]

    removed_count = 0
    for _, name, _, _ in src + tst:
        bf = buildfile_uuid(name)
        fr = fileref_uuid(name)
        before = content
        content = remove_uuid_lines(content, bf)
        content = remove_uuid_lines(content, fr)
        if content != before:
            removed_count += 1

    print(f"    Scrubbed {removed_count} file refs across PBXBuildFile / PBXFileReference / PBXGroup / PBXSourcesBuildPhase")
    return content


# ─────────────────────────────────────────────────────────────────────────────
# main
# ─────────────────────────────────────────────────────────────────────────────

def parse_features_arg(s: Optional[str]) -> set[str]:
    if not s:
        return set()
    out: set[str] = set()
    for raw in s.split(","):
        v = raw.strip().lower()
        if not v:
            continue
        if v not in ALL_FEATURE_IDS:
            print(f"  WARNING: Unknown feature id: {v}", file=sys.stderr)
            continue
        out.add(v)
    return out


def main() -> int:
    parser = argparse.ArgumentParser(add_help=True, description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--features", default=None,
                        help="Comma-separated feature ids to add (default: all when no remove flag is set)")
    parser.add_argument("--remove-features", default=None,
                        help="Comma-separated feature ids to remove")
    parser.add_argument("pbxproj", help="Path to project.pbxproj")
    args = parser.parse_args()

    add_set = parse_features_arg(args.features)
    rem_set = parse_features_arg(args.remove_features)

    # Default: add every feature (back-compat with the old monolithic invocation).
    if not add_set and not rem_set:
        add_set = set(ALL_FEATURE_IDS)

    with open(args.pbxproj, "r") as f:
        content = f.read()

    if rem_set:
        content = remove_features(content, rem_set)
    if add_set:
        content = add_features(content, add_set)

    with open(args.pbxproj, "w") as f:
        f.write(content)

    print(f"\n  Wrote {args.pbxproj}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
