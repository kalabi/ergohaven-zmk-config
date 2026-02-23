#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOARD="ergohaven"
DOCKER_IMAGE="zmkfirmware/zmk-build-arm:stable"
FIRMWARE_DIR="$SCRIPT_DIR/firmware"

# --- Target definitions ---
# Format: NAME|SHIELD|KEYMAP|SNIPPET|CMAKE_ARGS|ARTIFACT_NAME
TARGETS=(
    "velvet_v3_left|velvet_v3_left||studio-rpc-usb-uart|-DCONFIG_ZMK_STUDIO=y|"
    "velvet_v3_left_ruen|velvet_v3_left|velvet_v3_ruen|studio-rpc-usb-uart|-DCONFIG_ZMK_STUDIO=y|velvet_v3_left_ruen-ergohaven-zmk"
    "velvet_v3_right|velvet_v3_right||||"
    "velvet_v3_qube|velvet_v3_qube qube dongle_screen||studio-rpc-usb-uart|-DCONFIG_ZMK_STUDIO=y|velvet_v3_qube-ergohaven-zmk"
    "velvet_v3_qube_ruen|velvet_v3_qube qube dongle_screen|velvet_v3_ruen|studio-rpc-usb-uart|-DCONFIG_ZMK_STUDIO=y|velvet_v3_qube_ruen-ergohaven-zmk"
    "velvet_v3_left_qube|velvet_v3_left_qube||||"
    "settings_reset|settings_reset||||"
)

# Targets built by default (no arguments)
DEFAULT_TARGETS=(
    "velvet_v3_left_ruen"
    "velvet_v3_right"
)

# --- Functions ---

usage() {
    echo "Usage: $0 [options] [target ...]"
    echo ""
    echo "Options:"
    echo "  --init     Initialize west workspace only"
    echo "  --clean    Remove build directories"
    echo "  --list     List available targets"
    echo "  -h,--help  Show this help"
    echo ""
    echo "If no targets specified, default targets are built: ${DEFAULT_TARGETS[*]}"
    echo ""
    echo "Available targets:"
    for t in "${TARGETS[@]}"; do
        echo "  $(echo "$t" | cut -d'|' -f1)"
    done
}

init_workspace() {
    echo "==> Initializing west workspace..."
    if [ ! -d "$SCRIPT_DIR/.west" ]; then
        docker run --rm \
            -v "$SCRIPT_DIR:/workspace" \
            -w /workspace \
            "$DOCKER_IMAGE" \
            bash -c "west init -l config"
    else
        echo "    .west already exists, skipping init"
    fi

    echo "==> Updating west modules..."
    docker run --rm \
        -v "$SCRIPT_DIR:/workspace" \
        -w /workspace \
        "$DOCKER_IMAGE" \
        bash -c "west update"

    echo "==> West workspace ready"
}

build_target() {
    local target_def="$1"
    local name shield keymap snippet cmake_args artifact_name

    IFS='|' read -r name shield keymap snippet cmake_args artifact_name <<< "$target_def"

    echo "==> Building target: $name"
    echo "    Shield: $shield"
    [ -n "$keymap" ] && echo "    Keymap: $keymap"
    [ -n "$snippet" ] && echo "    Snippet: $snippet"

    local build_cmd="west zephyr-export && west build -s zmk/app -b $BOARD -d build/$name -p always"
    build_cmd+=" -- -DSHIELD=\"$shield\""
    build_cmd+=" -DZMK_CONFIG=/workspace/config"

    if [ -n "$snippet" ]; then
        build_cmd+=" -DSNIPPET=\"$snippet\""
    fi

    if [ -n "$cmake_args" ]; then
        build_cmd+=" $cmake_args"
    fi

    if [ -n "$keymap" ]; then
        build_cmd+=" -DKEYMAP_FILE=/workspace/config/$keymap.keymap"
    fi

    docker run --rm \
        -v "$SCRIPT_DIR:/workspace" \
        -w /workspace \
        "$DOCKER_IMAGE" \
        bash -c "$build_cmd"

    # Copy .uf2 to firmware/
    mkdir -p "$FIRMWARE_DIR"
    local uf2_file="$SCRIPT_DIR/build/$name/zephyr/zmk.uf2"
    if [ -f "$uf2_file" ]; then
        local out_name="${artifact_name:-$name}"
        cp "$uf2_file" "$FIRMWARE_DIR/${out_name}.uf2"
        echo "    => firmware/${out_name}.uf2"
    else
        echo "    WARNING: $uf2_file not found"
    fi
}

find_target() {
    local name="$1"
    for t in "${TARGETS[@]}"; do
        if [ "$(echo "$t" | cut -d'|' -f1)" = "$name" ]; then
            echo "$t"
            return 0
        fi
    done
    return 1
}

clean_builds() {
    echo "==> Cleaning build directories..."
    rm -rf "$SCRIPT_DIR"/build/*/
    rm -rf "$FIRMWARE_DIR"
    echo "    Done"
}

# --- Main ---

DO_INIT=0
DO_CLEAN=0
DO_LIST=0
SELECTED_TARGETS=()

for arg in "$@"; do
    case "$arg" in
        --init)  DO_INIT=1 ;;
        --clean) DO_CLEAN=1 ;;
        --list)  DO_LIST=1 ;;
        -h|--help) usage; exit 0 ;;
        *)       SELECTED_TARGETS+=("$arg") ;;
    esac
done

if [ "$DO_LIST" -eq 1 ]; then
    for t in "${TARGETS[@]}"; do
        echo "$(echo "$t" | cut -d'|' -f1)"
    done
    exit 0
fi

if [ "$DO_CLEAN" -eq 1 ]; then
    clean_builds
    exit 0
fi

if [ "$DO_INIT" -eq 1 ] && [ ${#SELECTED_TARGETS[@]} -eq 0 ]; then
    init_workspace
    exit 0
fi

# Ensure workspace is initialized before building
if [ ! -d "$SCRIPT_DIR/.west" ]; then
    init_workspace
fi

# Determine which targets to build
if [ ${#SELECTED_TARGETS[@]} -eq 0 ]; then
    # Use default targets
    BUILD_TARGETS=()
    for name in "${DEFAULT_TARGETS[@]}"; do
        BUILD_TARGETS+=("$(find_target "$name")")
    done
else
    BUILD_TARGETS=()
    for name in "${SELECTED_TARGETS[@]}"; do
        target_def=$(find_target "$name")
        if [ $? -ne 0 ]; then
            echo "ERROR: Unknown target '$name'"
            echo "Use --list to see available targets"
            exit 1
        fi
        BUILD_TARGETS+=("$target_def")
    done
fi

# Build each target
FAILED=()
for target_def in "${BUILD_TARGETS[@]}"; do
    name=$(echo "$target_def" | cut -d'|' -f1)
    if build_target "$target_def"; then
        echo "    OK: $name"
    else
        echo "    FAILED: $name"
        FAILED+=("$name")
    fi
    echo ""
done

# Summary
echo "================================"
echo "Build complete: $((${#BUILD_TARGETS[@]} - ${#FAILED[@]}))/${#BUILD_TARGETS[@]} succeeded"
if [ ${#FAILED[@]} -gt 0 ]; then
    echo "Failed targets: ${FAILED[*]}"
    exit 1
fi
echo "Firmware files in: $FIRMWARE_DIR/"
ls -la "$FIRMWARE_DIR/"*.uf2 2>/dev/null || true
