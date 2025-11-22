#!/usr/bin/env bash

# directory containing mods
MODS_DIR="mods"
DIST_DIR="dist"

# ignore patterns
IGNORE_FILES="(.git|.gitkeep|.DS_Store|Thumbs.db)"

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

    # read values from json
    NAME=$(grep -oP '"name":\s*"\K[^"]+' "$INFO")
    VERSION=$(grep -oP '"version":\s*"\K[^"]+' "$INFO")

    # version logic
    if [ "$FLAG_GIT" = true ]; then
        TAG=$(get_version_from_git)
        [ -z "$TAG" ] && { echo "ERROR: No git tags!"; exit 1; }
        TAG=${TAG#v}
        VERSION="$TAG"
    elif [ "$FLAG_PATCH" = true ]; then
        VERSION=$(increase_patch "$VERSION")
        # update json inline
        sed -i'' -E "s/\"version\": \"[0-9.]+\"/\"version\": \"$VERSION\"/" "$INFO"
    fi

    ZIP="$DIST_DIR/${NAME}_${VERSION}.zip"

    echo "Building $NAME ($VERSION) -> $ZIP"

    rm -f "$ZIP"
    # copy mod content into zip, ignoring files
    (cd "$DIR" && \
        zip -r "../$ZIP" . -x "*$IGNORE_FILES*")
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
        NAME=$(grep -oP '"name":\s*"\K[^"]+' "$INFO")
        [ "$NAME" = "$TARGET_MOD" ] && build_mod "$DIR"
    done
fi
echo "Build complete."
