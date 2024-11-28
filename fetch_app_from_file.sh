#!/bin/bash

# Initialiser la variable pour stocker le JSON
json="{"
json+="\"include\":["

first_combo=true

# Récupérer la liste des applications
apps=$(yq '.apps | keys | .[]' test.yaml)

for app in $apps; do
    enabled=$(yq ".apps.$app.enabled" test.yaml)
    
    # Ne traiter que les applications activées
    if [ "$enabled" = "true" ]; then
        # Récupérer tous les patchs disponibles
        patches=$(yq ".apps.$app.revanced | keys | .[]" test.yaml)
        
        # Parcourir chaque patch
        for patch in $patches; do
            patch_enabled=$(yq ".apps.$app.revanced.$patch.enabled" test.yaml)
            if [ "$patch_enabled" = "true" ]; then
                if [ "$first_combo" = "true" ]; then
                    first_combo=false
                else
                    json+=","
                fi
                json+="{\"app\":\"$app\",\"patch\":\"$patch\"}"
            fi
        done
    fi
done

json+="]}"

# Échapper les caractères spéciaux pour GitHub Actions
escaped_json=$(echo "$json" | jq -c .)
echo "$escaped_json"
