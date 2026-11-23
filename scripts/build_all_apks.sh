#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# RDX IDE APK Build & Output Packager
# Builds the app (ai.rdx.ide). --x86_64 builds the x86_64 APK instead of the arm64 one (gradle -Pabi=x86_64);
# --chroot builds the arm64 APK with the Ubuntu chroot's Linux bridge (gradle -Pchroot=true). The normal arm64 release
# leaves that bridge out; the x86_64 APK always has it. Debug builds have it unless gradle -Pchroot=false.
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/output"

MODE="debug"
ABI="arm64"
CHROOT=""
for arg in "$@"; do
    case "$arg" in
        --release|-r) MODE="release" ;;
        --x86_64) ABI="x86_64" ;;
        --chroot) CHROOT="true" ;;
    esac
done
# file names: the arm64 build has none of these suffixes (the in-app updater asks for the name of its own build)
SUFFIX=""
GRADLE_ARCHIVE="rdxIde"
OUTPUT_NAME="RDX IDE"
BRIDGE_ARCH="arm64"
GRADLE_ARGS=(-Pabi="${ABI}")
if [[ "${ABI}" == "x86_64" ]]; then
    SUFFIX="-x86_64"
    GRADLE_ARCHIVE="rdxIde-x86_64"
    OUTPUT_NAME="RDX IDE-x86_64"
    BRIDGE_ARCH="amd64"
elif [[ "${CHROOT}" == "true" ]]; then
    SUFFIX="-chroot"
    GRADLE_ARCHIVE="rdxIde-chroot"
    OUTPUT_NAME="RDX IDE-chroot"
    GRADLE_ARGS+=(-Pchroot=true)
fi

echo "================================================================="
echo "🚀 Building RDX IDE Packages in [${MODE^^}] mode for ${ABI}${SUFFIX:+ (${SUFFIX#-})}"
echo "================================================================="

# The version from version.json: the newer of its stable release and its beta, like the Gradle build. A missing or
# broken file stops here (Gradle says what is wrong with it).
VERSION_NAME=$(python3 "${SCRIPT_DIR}/release_version.py" name "${ROOT_DIR}/version.json")
VERSION_CODE=$(python3 "${SCRIPT_DIR}/release_version.py" code "${ROOT_DIR}/version.json")
CHANNEL=$(python3 "${SCRIPT_DIR}/release_version.py" channel "${ROOT_DIR}/version.json")

echo "📦 Version Name: v${VERSION_NAME} (Code: ${VERSION_CODE}, ${CHANNEL})"
mkdir -p "${OUTPUT_DIR}"

APKS_SRC="${ROOT_DIR}/app/build/outputs/apk"
if [[ "${MODE}" == "release" ]]; then
    echo "🔨 Compiling Release (:app:assembleRelease)..."
    "${ROOT_DIR}/gradlew" -p "${ROOT_DIR}" :app:assembleRelease "${GRADLE_ARGS[@]}"
    # the release asset; the in-app updater downloads releases/download/v<version>/RDX IDE-v<version><suffix>.apk
    cp "${APKS_SRC}/release/${GRADLE_ARCHIVE}-release.apk" "${OUTPUT_DIR}/RDX IDE-v${VERSION_NAME}${SUFFIX}.apk"
else
    echo "🔨 Compiling Debug (:app:assembleDebug)..."
    "${ROOT_DIR}/gradlew" -p "${ROOT_DIR}" :app:assembleDebug "${GRADLE_ARGS[@]}"
    cp "${APKS_SRC}/debug/${GRADLE_ARCHIVE}-debug.apk" "${OUTPUT_DIR}/RDX IDE-v${VERSION_NAME}${SUFFIX}-debug.apk"

    # the APK ships the bridge xz-compressed; the uncompressed build is kept under app/build
    if [[ -f "${ROOT_DIR}/app/build/intermediates/agyIdeBridge/agy_ide_bridge" ]]; then
        cp "${ROOT_DIR}/app/build/intermediates/agyIdeBridge/agy_ide_bridge" "${OUTPUT_DIR}/agy_ide_bridge-v${VERSION_NAME}-android-${BRIDGE_ARCH}"
    fi
fi

echo ""
echo "================================================================="
echo "✅ Build Complete! Generated Artifacts in: ${OUTPUT_DIR}"
echo "================================================================="
ls -lh "${OUTPUT_DIR}"/* 2>/dev/null || true
echo "================================================================="
