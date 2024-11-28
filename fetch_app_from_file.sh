#!/bin/bash

# Créer un tableau pour stocker les combinaisons app/patch
echo "{"
echo "  \"include\": ["

first_combo=true

# Récupérer la liste des applications
apps=$(yq '.apps | keys | .[]' test.yaml)

for app in $apps; do
    enabled=$(yq ".apps.$app.enabled" test.yaml)
    
    # Ne traiter que les applications activées
    if [ "$enabled" = "true" ]; then
        # Vérifier Inotia
        inotia_enabled=$(yq ".apps.$app.revanced.inotia.enabled" test.yaml)
        if [ "$inotia_enabled" = "true" ]; then
            if [ "$first_combo" = "true" ]; then
                first_combo=false
            else
                echo ","
            fi
            echo "    {\"app\": \"$app\", \"patch\": \"inotia\"}"
        fi
        
        # Vérifier ReVanced
        revanced_enabled=$(yq ".apps.$app.revanced.revanced.enabled" test.yaml)
        if [ "$revanced_enabled" = "true" ]; then
            if [ "$first_combo" = "true" ]; then
                first_combo=false
            else
                echo ","
            fi
            echo "    {\"app\": \"$app\", \"patch\": \"revanced\"}"
        fi
    fi
done

echo "  ]"
echo "}"
