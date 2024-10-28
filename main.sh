#!/bin/bash

# L'application à construire est passée en paramètre
APP_NAME="$1"
if [ -z "$APP_NAME" ]; then
    echo "Error: App name must be provided"
    exit 1
fi

# Lecture de la configuration depuis test.yaml
APP_VERSION=$(yq e ".apps.$APP_NAME.version" test.yaml)
BUILD_MODE=$(yq e ".apps.$APP_NAME.build_mode" test.yaml)
OUTPUT_APK="revanced-$APP_NAME.apk"

# Création du dossier de travail
WORK_DIR="revanced_build_$APP_NAME"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Fonction pour vérifier si une commande s'est bien exécutée
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Téléchargement de l'APK
echo "Downloading $APP_NAME APK..."
if [ "$APP_VERSION" = "auto" ] || [ "$APP_VERSION" = "latest" ]; then
    ../fetch_link.sh google-inc $APP_NAME latest False universal
else
    ../fetch_link.sh google-inc $APP_NAME $APP_VERSION False universal
fi
check_error "Failed to download $APP_NAME APK"

# Téléchargement des composants ReVanced
echo "Downloading ReVanced components..."
for repo in "inotia00/revanced-integrations:apk:revanced-integrations.apk" \
           "inotia00/revanced-patches:jar:revanced-patches.jar" \
           "inotia00/revanced-cli:jar:revanced-cli-all.jar"; do
    IFS=':' read -r repo_path type output <<< "$repo"
    ../script.sh "$repo_path" "$type" "$output"
    check_error "Failed to download $output"
done

# Génération des options de patch
echo "Generating patch options..."
java -jar revanced-cli-all.jar options --path options.json --overwrite revanced-patches.jar
check_error "Failed to generate patch options"

# Construction de ReVanced Extended
echo "Building ReVanced for $APP_NAME..."
EXCLUDED_PATCHES=$(yq e ".apps.$APP_NAME.patches.excluded[]" test.yaml | tr '\n' ' ' | sed 's/ $//')
INCLUDED_PATCHES=$(yq e ".apps.$APP_NAME.patches.included[]" test.yaml | tr '\n' ' ' | sed 's/ $//')
ROOT_PATCH=$(yq e ".apps.$APP_NAME.root_patch" test.yaml)

PATCH_ARGS=""
if [ ! -z "$EXCLUDED_PATCHES" ]; then
    for patch in $EXCLUDED_PATCHES; do
        PATCH_ARGS="$PATCH_ARGS -e \"$patch\""
    done
fi

if [ ! -z "$INCLUDED_PATCHES" ]; then
    for patch in $INCLUDED_PATCHES; do
        PATCH_ARGS="$PATCH_ARGS -i \"$patch\""
    done
fi

if [ ! -z "$ROOT_PATCH" ]; then
    PATCH_ARGS="$PATCH_ARGS -e \"$ROOT_PATCH\""
fi

eval "java -jar revanced-cli-all.jar patch \
    -b revanced-patches.jar \
    -m revanced-integrations.apk \
    --options options.json \
    $PATCH_ARGS \
    -o \"$OUTPUT_APK\" \
    \"$APP_NAME-*.apk\""
check_error "Failed to build ReVanced for $APP_NAME"

# Déplacer l'APK vers le répertoire parent
mv "$OUTPUT_APK" ../

echo "Build completed successfully!"
echo "Output file: $OUTPUT_APK"
