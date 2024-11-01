#!/bin/bash

# L'application et le patch à utiliser sont passés en paramètres
APP_NAME="$1"
PATCH_NAME="$2"

if [ -z "$APP_NAME" ] || [ -z "$PATCH_NAME" ]; then
    echo "Error: Both app name and patch name must be provided"
    exit 1
fi

ls
cat test.yaml
echo $(yq e '.apps | keys | .[]' test.yaml)

# Lecture de la configuration depuis test.yaml
APP_ENABLED=$(yq e ".apps.$APP_NAME.enabled" test.yaml)
if [ "$APP_ENABLED" != "true" ]; then
    echo "Error: App $APP_NAME is not enabled in config"
    exit 1
fi

PATCH_ENABLED=$(yq e ".apps.$APP_NAME.revanced.$PATCH_NAME.enabled" test.yaml)
if [ "$PATCH_ENABLED" != "true" ]; then
    echo "Error: Patch $PATCH_NAME is not enabled for $APP_NAME in config"
    exit 1
fi

APP_VERSION=$(yq e ".apps.$APP_NAME.revanced.$PATCH_NAME.app_version" test.yaml)
BUILD_MODE=$(yq e ".apps.$APP_NAME.build_mode" test.yaml)
OUTPUT_APK="revanced-$APP_NAME-$PATCH_NAME.apk"

# Création du dossier de travail
WORK_DIR="revanced_build_${APP_NAME}_${PATCH_NAME}"
mkdir -p "$WORK_DIR"
cp test.yaml "$WORK_DIR"
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
    ../fetch_link.sh "$(yq e ".apps.$APP_NAME.download.apkmirror" test.yaml)" latest false "$(yq e ".apps.$APP_NAME.arch" test.yaml)"
else
    ../fetch_link.sh "$(yq e ".apps.$APP_NAME.download.apkmirror" test.yaml)" "$APP_VERSION" false "$(yq e ".apps.$APP_NAME.arch" test.yaml)"
fi
check_error "Failed to download $APP_NAME APK"

# Téléchargement des composants ReVanced spécifiques au patch
echo "Downloading ReVanced components for $PATCH_NAME..."
CLI_SOURCE=$(yq e ".apps.$APP_NAME.revanced.$PATCH_NAME.cli.source" test.yaml)
CLI_VERSION=$(yq e ".apps.$APP_NAME.revanced.$PATCH_NAME.cli.version" test.yaml)
INT_SOURCE=$(yq e ".apps.$APP_NAME.revanced.$PATCH_NAME.integrations.source" test.yaml)
INT_VERSION=$(yq e ".apps.$APP_NAME.revanced.$PATCH_NAME.integrations.version" test.yaml)
PATCHES_SOURCE=$(yq e ".apps.$APP_NAME.revanced.$PATCH_NAME.patches.source" test.yaml)
PATCHES_VERSION=$(yq e ".apps.$APP_NAME.revanced.$PATCH_NAME.patches.version" test.yaml)

../script.sh "$INT_SOURCE" "apk" "revanced-integrations.apk"
check_error "Failed to download revanced-integrations.apk"

../script.sh "$PATCHES_SOURCE" "jar" "revanced-patches.jar"
check_error "Failed to download revanced-patches.jar"

../script.sh "$CLI_SOURCE" "jar" "revanced-cli-all.jar"
check_error "Failed to download revanced-cli-all.jar"

# Génération des options de patch
echo "Generating patch options..."
java -jar revanced-cli-all.jar options --path options.json --overwrite revanced-patches.jar
check_error "Failed to generate patch options"

# Construction de ReVanced
echo "Building ReVanced for $APP_NAME with $PATCH_NAME patches..."
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

ls
eval "java -jar revanced-cli-all.jar patch \
    -b revanced-patches.jar \
    -m revanced-integrations.apk \
    --options options.json \
    $PATCH_ARGS \
    -o \"$OUTPUT_APK\" \
    \"$APP_NAME-$APP_VERSION.apk\""
check_error "Failed to build ReVanced for $APP_NAME with $PATCH_NAME patches"

# Déplacer l'APK vers le répertoire parent
mv "$OUTPUT_APK" ../

echo "Build completed successfully!"
echo "Output file: $OUTPUT_APK"
