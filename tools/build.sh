#!/usr/bin/env bash

# ==========================================================
# Factorio Mod Builder (fixed minimal version)
# Works on macOS, Linux, Windows Git-Bash
# ==========================================================

MODS_DIR="mods"
DIST_DIR="dist"

# ignore patterns (glob, NOT regex)
IGNORE_FILES="*.git* *.gitkeep* *.DS_Store* *Thumbs.db*"

usage() {
    echo "Usage: $0 [-m MOD] [-p] [-g] [-h]"
    echo
    echo "Options:"
    echo "  -m <MOD>   Build only specific mod (from its info.json name)"
    echo "  -p         Increase PATCH version before build"
    echo "  -g         Use version from latest git tag (no patch increment)"
    echo "  -h         Show help"
    echo
    exit 0
}

# parse args
while getopts "m:pgh" opt; do
    case $opt in
        m) TARGET_MOD="$OPTARG" ;;
        p) FLAG_PATCH=true ;;
        g) FLAG_GIT=true ;;
        h) usage ;;
    esac
done

mkdir -p "$DIST_DIR"

get_version_from_git() {
    git describe --tags --abbrev=0 2>/dev/null || echo ""
}

increase_patch() {
    IFS='.' read -r X Y Z <<< "$1"
    Z=$((Z+1))
    echo "$X.$Y.$Z"
}

build_mod() {
    local DIR="$1"
    local INFO="$DIR/info.json"

    # skip empty folders
    [ -f "$INFO" ] || return

    # ---- read values from json (no grep -P!) ----
    NAME=$(sed -n 's/.*"name"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$INFO")
    VERSION=$(sed -n 's/.*"version"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$INFO")

    # version logic
    if [ "$FLAG_GIT" = true ]; then
        TAG=$(get_version_from_git)
        [ -z "$TAG" ] && { echo "ERROR: No git tags!"; exit 1; }
        TAG=${TAG#v}
        VERSION="$TAG"
    elif [ "$FLAG_PATCH" = true ]; then
        VERSION=$(increase_patch "$VERSION")
        # update json inline (portable sed)
        # macOS uses sed -i '', Linux sed -i
        if sed --version >/dev/null 2>&1; then
            sed -i -E "s/\"version\": \"[0-9.]+\"/\"version\": \"$VERSION\"/" "$INFO"
        else
            sed -i '' -E "s/\"version\": \"[0-9.]+\"/\"version\": \"$VERSION\"/" "$INFO"
        fi
    fi

    ZIP="$DIST_DIR/${NAME}_${VERSION#v}.zip"

    echo "Building $NAME ($VERSION) -> $ZIP"

    rm -f "$ZIP"

    # Create zip FROM OUTSIDE each mod folder
    (cd "$MODS_DIR" && zip -r "../$ZIP" "$(basename "$DIR")" -x $IGNORE_FILES)


}

# iterate mods
if [ -z "$TARGET_MOD" ]; then
    # all
    for DIR in "$MODS_DIR"/*; do
        [ -d "$DIR" ] && build_mod "$DIR"
    done
else
    # only target
    for DIR in "$MODS_DIR"/*; do
        INFO="$DIR/info.json"
        [ -f "$INFO" ] || continue
        NAME=$(sed -n 's/.*"name"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$INFO")
        [ "$NAME" = "$TARGET_MOD" ] && build_mod "$DIR"
    done
fi

echo "Build complete."
