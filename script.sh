#!/bin/bash

fetchToolsAPI() {
    rv=$1
    EXT=$2
    name_dl=$3

    # Récupération des informations de la dernière release
    LATEST_RELEASE=$(curl -s --fail-early --connect-timeout 2 --max-time 5 "https://api.github.com/repos/$rv/releases/latest")

    # Vérification si la release existe
    if [ "$(echo $LATEST_RELEASE | grep -c 'message')" -gt 0 ]; then
        echo "Erreur: Impossible de trouver la dernière release"
        return 1
    fi

    # Recherche et téléchargement de l'asset avec l'extension spécifiée
    ASSET_URL=$(echo $LATEST_RELEASE | jq -r --arg ext "$EXT" '.assets[] | select(.browser_download_url | endswith(".\($ext)")) | .browser_download_url' | head -n 1)

    if [ -z "$ASSET_URL" ]; then
        echo "Aucun asset trouvé avec l'extension .$EXT"
        return 1
    fi

    echo "Téléchargement de $name_dl..."
    curl -L -o "$name_dl" "$ASSET_URL"

    echo "Téléchargement terminé"
}

# Example usage
fetchToolsAPI "$1" "$2" "$3"
