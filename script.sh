#!/bin/bash

# Fonction pour télécharger et construire une application
build_app() {
    local app_name=$1
    local patches_source=$2
    local integrations_source=$3
    local cli_source=$4
    local rv_brand=$5
    local build_mode=$6
    local apkmirror_dlurl=$7

    echo "Construction de $app_name"

    # Téléchargement des dépendances
    wget -O revanced-cli.jar "https://github.com/$cli_source/releases/latest/download/revanced-cli-all.jar"
    wget -O revanced-patches.jar "https://github.com/$patches_source/releases/latest/download/revanced-patches-all.jar"
    wget -O revanced-integrations.apk "https://github.com/$integrations_source/releases/latest/download/revanced-integrations.apk"

    # Téléchargement de l'APK
    apk_filename="${app_name,,}-latest.apk"
    wget -O "$apk_filename" "$apkmirror_dlurl/download-latest-apk"

    # Génération des options de patch
    java -jar revanced-cli.jar options --path options.json --overwrite revanced-patches.jar

    # Construction de l'application
    java -jar revanced-cli.jar patch "$apk_filename" -p -o "${app_name,,}-revanced.apk" -b revanced-patches.jar --options=options.json

    echo "$app_name construit avec succès"
}

# Lecture du fichier YAML
while IFS= read -r line
do
    if [[ $line =~ ^[A-Za-z-]+: ]]; then
        app_name=$(echo "$line" | cut -d':' -f1)
        patches_source=$(grep 'patches-source:' -A 1 test.yaml | tail -n 1 | awk '{print $2}' | tr -d '"')
        integrations_source=$(grep 'integrations-source:' -A 1 test.yaml | tail -n 1 | awk '{print $2}' | tr -d '"')
        cli_source=$(grep 'cli-source:' -A 1 test.yaml | tail -n 1 | awk '{print $2}' | tr -d '"')
        rv_brand=$(grep 'rv-brand:' -A 1 test.yaml | tail -n 1 | awk '{print $2}' | tr -d '"')
        build_mode=$(grep 'build-mode:' -A 1 test.yaml | tail -n 1 | awk '{print $2}' | tr -d '"')
        apkmirror_dlurl=$(grep 'apkmirror-dlurl:' -A 1 test.yaml | tail -n 1 | awk '{print $2}' | tr -d '"')

        build_app "$app_name" "$patches_source" "$integrations_source" "$cli_source" "$rv_brand" "$build_mode" "$apkmirror_dlurl"
    fi
done < test.yaml

echo "Toutes les applications ont été construites"