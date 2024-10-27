#!/bin/bash

# Configuration
YOUTUBE_VERSION="19.16.39"
OUTPUT_APK="revanced-extended.apk"

# Fonction pour vérifier si une commande s'est bien exécutée
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Création du dossier de travail
WORK_DIR="revanced_build"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"


# Téléchargement de YouTube APK
echo "Downloading YouTube APK..."
../fetch_link.sh google-inc youtube $YOUTUBE_VERSION False universal
check_error "Failed to download YouTube APK"

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
echo "Building ReVanced Extended..."
java -jar revanced-cli-all.jar patch \
    -b revanced-patches.jar \
    -m revanced-integrations.apk \
    --options options.json \
    -e "GmsCore support" \
    -o "$OUTPUT_APK" \
    "youtube-$YOUTUBE_VERSION.apk"
check_error "Failed to build ReVanced Extended"

echo "Build completed successfully!"
echo "Output file: $OUTPUT_APK"

