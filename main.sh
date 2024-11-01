#!/bin/bash

# Vérification des paramètres
APP_NAME="$1"
PATCH_NAME="$2"

if [ -z "$APP_NAME" ] || [ -z "$PATCH_NAME" ]; then
    echo "Error: App name and Patch name must be provided"
    exit 1
fi

ls
cat test.yaml

# Lecture de la configuration depuis test.yaml
APP_ENABLED=$(yq e ".apps.$APP_NAME.enabled" test.yaml)
if [ "$APP_ENABLED" != "true" ]; then
    echo "Error: App $APP_NAME is not enabled in config"
    exit 1
fi

PATCH_ENABLED=$(yq e ".apps.$APP_NAME.$PATCH_NAME.enabled" test.yaml)
if [ "$PATCH_ENABLED" != "true" ]; then
    echo "Error: Patch $PATCH_NAME for app $APP_NAME is not enabled in config"
    exit 1
fi

APP_VERSION=$(yq e ".apps.$APP_NAME.download.version" test.yaml)
BUILD_MODE=$(yq e ".apps.$APP_NAME.build_mode" test.yaml)
PATCH_VERSION=$(yq e ".apps.$APP_NAME.$PATCH_NAME.app_version" test.yaml)
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
echo "Downloading $APP_NAME APK with patch $PATCH_NAME..."
if [ "$APP_VERSION" = "auto" ] || [ "$APP_VERSION" = "latest" ]; then
    ../fetch_link.sh "$(yq e ".apps.$APP_NAME.download.apkmirror" test.yaml)" latest false "$(yq e ".apps.$APP_NAME.arch" test.yaml)"
else
    ../fetch_link.sh "$(yq e ".apps.$APP_NAME.download.apkmirror" test.yaml)" "$APP_VERSION" false "$(yq e ".apps.$APP_NAME.arch" test.yaml)"
fi
check_error "Failed to download $APP_NAME APK"

# Téléchargement des composants ReVanced spécifiques au patch
echo "Downloading ReVanced components for patch $PATCH_NAME..."
PATCH_CONFIG_PREFIX=".apps.$APP_NAME.$PATCH_NAME"
for repo in "$(yq e "${PATCH_CONFIG_PREFIX}.cli.source" test.yaml):jar:$(yq e "${PATCH_CONFIG_PREFIX}.cli.version" test.yaml)" \
            "$(yq e "${PATCH_CONFIG_PREFIX}.integrations.source" test.yaml):apk:$(yq e "${PATCH_CONFIG_PREFIX}.integrations.version" test.yaml)" \
            "$(yq e "${PATCH_CONFIG_PREFIX}.patches.source" test.yaml):jar:$(yq e "${PATCH_CONFIG_PREFIX}.patches.version" test.yaml)"; do
    IFS=':' read -r repo_path type version <<< "$repo"
    output_file=""
    case $type in
        apk)
            output_file="${repo_path##*/}.apk"
            ;;
        jar)
            output_file="${repo_path##*/}.jar"
            ;;
        *)
            echo "Unknown type: $type"
            exit 1
            ;;
    esac
    ../script.sh "$repo_path" "$type" "$output_file" "$version"
    check_error "Failed to download $output_file"
done

# Génération des options de patch
echo "Generating patch options for $PATCH_NAME..."
java -jar revanced-cli-all.jar options --path options.json --overwrite revanced-patches.jar
check_error "Failed to generate patch options"

# Construction de ReVanced Extended
echo "Building ReVanced for $APP_NAME with patch $PATCH_NAME..."
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
check_error "Failed to build ReVanced for $APP_NAME with patch $PATCH_NAME"

# Déplacer l'APK vers le répertoire parent
mv "$OUTPUT_APK" ../

echo "Build completed successfully!"
echo "Output file: $OUTPUT_APK"
