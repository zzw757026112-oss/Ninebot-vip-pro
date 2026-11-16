#!/usr/bin/env python3
"""Generate NinebotPro.xcodeproj/project.pbxproj from the source tree.

Run from the rebuild root:  python3 gen_pbxproj.py
Deterministic 24-hex UUIDs are derived from each file's project path,
so re-running the script produces the same project file.
Not part of the Xcode project itself; kept here so the project can be
regenerated if files are added or removed.
"""
import hashlib
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ_DIR = os.path.join(ROOT, "NinebotPro")
SRC_DIR = os.path.join(PROJ_DIR, "NinebotPro")


def uuid(name: str) -> str:
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()


# Collect Swift files, in a stable order.
swift_files = []
for dirpath, _dirs, files in os.walk(SRC_DIR):
    for name in sorted(files):
        if name.endswith(".swift"):
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, PROJ_DIR)  # e.g. NinebotPro/Models/X.swift
            swift_files.append(rel)
swift_files.sort()

# Fixed IDs for the structural objects.
IDS = {
    "project": uuid("PBXProject NinebotPro"),
    "target": uuid("PBXNativeTarget NinebotPro"),
    "product": uuid("PBXFileReference NinebotPro.app"),
    "main_group": uuid("PBXGroup main"),
    "product_group": uuid("PBXGroup Products"),
    "app_group": uuid("PBXGroup NinebotPro"),
    "sources_phase": uuid("PBXSourcesBuildPhase"),
    "frameworks_phase": uuid("PBXFrameworksBuildPhase"),
    "resources_phase": uuid("PBXResourcesBuildPhase"),
    "project_config_list": uuid("XCConfigurationList project"),
    "target_config_list": uuid("XCConfigurationList target"),
    "project_debug": uuid("XCBuildConfiguration project Debug"),
    "project_release": uuid("XCBuildConfiguration project Release"),
    "target_debug": uuid("XCBuildConfiguration target Debug"),
    "target_release": uuid("XCBuildConfiguration target Release"),
    "assets_ref": uuid("PBXFileReference Assets.xcassets"),
    "assets_build": uuid("PBXBuildFile Assets.xcassets"),
    "info_ref": uuid("PBXFileReference Info.plist"),
}

# One group per source folder, plus the app group itself.
folders = sorted({os.path.dirname(p) for p in swift_files})
group_id = {f: uuid("PBXGroup " + f) for f in folders}
group_id["NinebotPro"] = IDS["app_group"]

lines = []
lines.append("// !$*UTF8*$!")
lines.append("{")
lines.append("\tarchiveVersion = 1;")
lines.append("\tclasses = {")
lines.append("\t};")
lines.append("\tobjectVersion = 56;")
lines.append("\tobjects = {")

# --- PBXBuildFile for each Swift file + Assets ---
for rel in swift_files:
    lines.append(f"\t\t{uuid('PBXBuildFile ' + rel)} /* {os.path.basename(rel)} in Sources */ = {{isa = PBXBuildFile; fileRef = {uuid('PBXFileReference ' + rel)} /* {os.path.basename(rel)} */; }};")
lines.append(f"\t\t{IDS['assets_build']} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {IDS['assets_ref']} /* Assets.xcassets */; }};")

# --- PBXFileReference ---
for rel in swift_files:
    lines.append(f"\t\t{uuid('PBXFileReference ' + rel)} /* {os.path.basename(rel)} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {os.path.basename(rel)}; sourceTree = \"<group>\"; }};")
lines.append(f"\t\t{IDS['assets_ref']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
lines.append(f"\t\t{IDS['info_ref']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
lines.append(f"\t\t{IDS['product']} /* NinebotPro.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = NinebotPro.app; sourceTree = BUILT_PRODUCTS_DIR; }};")

# --- PBXFrameworksBuildPhase (empty: only system frameworks, linked implicitly) ---
lines.append(f"\t\t{IDS['frameworks_phase']} /* Frameworks */ = {{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; }};")

# --- PBXGroup ---
lines.append(f"\t\t{IDS['main_group']} = {{isa = PBXGroup; children = ({IDS['app_group']}, {IDS['product_group']}); sourceTree = \"<group>\"; }};")
lines.append(f"\t\t{IDS['product_group']} = {{isa = PBXGroup; children = ({IDS['product']}); name = Products; sourceTree = \"<group>\"; }};")
app_children = ([IDS['assets_ref'], IDS['info_ref']]
              + [group_id[f] for f in folders if f != "NinebotPro"]
              + [uuid('PBXFileReference ' + p) for p in swift_files if os.path.dirname(p) == "NinebotPro"])
lines.append(f"\t\t{IDS['app_group']} = {{isa = PBXGroup; children = ({', '.join(app_children)}); path = NinebotPro; sourceTree = \"<group>\"; }};")
for folder in folders:
    if folder == "NinebotPro":
        continue
    children = [uuid('PBXFileReference ' + p) for p in swift_files if os.path.dirname(p) == folder]
    lines.append(f"\t\t{group_id[folder]} = {{isa = PBXGroup; children = ({', '.join(children)}); name = {os.path.basename(folder)}; path = {os.path.basename(folder)}; sourceTree = \"<group>\"; }};")
# The app entry file lives directly in NinebotPro/ (not a subfolder).
# It is a child of the app group via a dedicated group entry:
# (handled below by adding its file ref to the app group children.)

# --- PBXNativeTarget ---
build_files = ", ".join(uuid('PBXBuildFile ' + p) for p in swift_files)
lines.append(f"\t\t{IDS['target']} = {{isa = PBXNativeTarget; buildConfigurationList = {IDS['target_config_list']} /* Build configuration list for PBXNativeTarget \"NinebotPro\" */; buildPhases = ({IDS['sources_phase']} /* Sources */, {IDS['frameworks_phase']} /* Frameworks */, {IDS['resources_phase']} /* Resources */); buildRules = (); dependencies = (); name = NinebotPro; productName = NinebotPro; productReference = {IDS['product']} /* NinebotPro.app */; productType = \"com.apple.product-type.application\"; }};")

# --- PBXProject ---
lines.append(f"\t\t{IDS['project']} = {{isa = PBXProject; attributes = {{LastSwiftUpdateCheck = 1500; LastUpgradeCheck = 1500; TargetAttributes = {{{IDS['target']} = {{CreatedOnToolsVersion = 15.0; }}; }}; }}; buildConfigurationList = {IDS['project_config_list']} /* Build configuration list for PBXProject \"NinebotPro\" */; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = zh-Hans; hasScannedForEncodings = 0; knownRegions = (zh-Hans, en, Base); mainGroup = {IDS['main_group']}; productRefGroup = {IDS['product_group']} /* Products */; projectDirPath = \"\"; projectRoot = \"\"; targets = ({IDS['target']}); }};")

# --- PBXResourcesBuildPhase ---
lines.append(f"\t\t{IDS['resources_phase']} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({IDS['assets_build']} /* Assets.xcassets in Resources */); runOnlyForDeploymentPostprocessing = 0; }};")

# --- PBXSourcesBuildPhase ---
lines.append(f"\t\t{IDS['sources_phase']} /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({build_files}); runOnlyForDeploymentPostprocessing = 0; }};")

# --- XCBuildConfiguration ---
def config(id_, name, settings):
    body = ";\n\t\t\t".join(f"{k} = {v}" for k, v in settings.items())
    return (f"\t\t{id_} /* {name} */ = {{isa = XCBuildConfiguration; buildSettings = {{\n\t\t\t{body};\n\t\t}}; name = {name}; }};")

project_common = {
    "ALWAYS_SEARCH_USER_PATHS": "NO",
    "CLANG_ANALYZER_NONNULL": "YES",
    "CLANG_CXX_LANGUAGE_STANDARD": '"gnu++20"',
    "CLANG_ENABLE_MODULES": "YES",
    "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "COPY_PHASE_STRIP": "NO",
    "CURRENT_PROJECT_VERSION": "1",
    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
    "GCC_C_LANGUAGE_STANDARD": "gnu11",
    "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
    "LOCALIZATION_PREFS": "zh-Hans",
    "MARKETING_VERSION": "1.1.0",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.hanlin.ninebotpro",
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
}
lines.append(config(IDS["project_debug"], "Debug", {**project_common, "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"'}))
lines.append(config(IDS["project_release"], "Release", project_common))

target_common = {
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "CODE_SIGN_STYLE": "Automatic",
    "INFOPLIST_FILE": "NinebotPro/Info.plist",
    "IPHONEOS_DEPLOYMENT_TARGET": "16.0",
    "LD_RUNPATH_SEARCH_PATHS": '"$(inherited) @executable_path/Frameworks"',
    "PRODUCT_BUNDLE_IDENTIFIER": "com.hanlin.ninebotpro",
    "PRODUCT_NAME": '"$(TARGET_NAME)"',
    "SWIFT_VERSION": "5.0",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
}
lines.append(config(IDS["target_debug"], "Debug", {**target_common, "SWIFT_OPTIMIZATION_LEVEL": '"-Onone"'}))
lines.append(config(IDS["target_release"], "Release", target_common))

# --- XCConfigurationList ---
lines.append(f"\t\t{IDS['project_config_list']} /* Build configuration list for PBXProject \"NinebotPro\" */ = {{isa = XCConfigurationList; buildConfigurations = ({IDS['project_debug']} /* Debug */, {IDS['project_release']} /* Release */); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};")
lines.append(f"\t\t{IDS['target_config_list']} /* Build configuration list for PBXNativeTarget \"NinebotPro\" */ = {{isa = XCConfigurationList; buildConfigurations = ({IDS['target_debug']} /* Debug */, {IDS['target_release']} /* Release */); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};")

lines.append("\t};")
lines.append(f"\trootObject = {IDS['project']} /* Project object */;")
lines.append("}")

out = os.path.join(PROJ_DIR, "NinebotPro.xcodeproj", "project.pbxproj")
with open(out, "w", encoding="utf-8") as fh:
    fh.write("\n".join(lines) + "\n")
print(f"Wrote {out} ({len(swift_files)} Swift files)")
for rel in swift_files:
    print(" ", rel)
