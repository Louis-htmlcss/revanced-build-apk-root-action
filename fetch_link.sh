#!/bin/bash

UserAgent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"

developer="$1"
appName="$2"
appVer="$3"
preferSplit="$4"
arch="$5"  

page1=$(curl -vsL -A "$UserAgent" "https://www.apkmirror.com/apk/$developer/$appName/$appName-$appVer-release" 2>&1)

canonicalUrl=$(pup -p --charset utf-8 'link[rel="canonical"] attr{href}' <<<"$page1")
if [[ "$canonicalUrl" == *"apk-download"* ]]; then
    url1="${canonicalUrl/"https://www.apkmirror.com/"//}"
else
    grep -q 'class="error404"' <<<"$page1" && echo noversion >&2 && exit 1

    bundles=$(pup -p --charset utf-8 ':parent-of(span.apkm-badge:contains("BUNDLE"))' <<<"$page1")
    readarray -t bundleUrls < <(pup -p --charset utf-8 'a.accent_color attr{href}' <<<"$bundles")

    apks=$(pup -p --charset utf-8 ':parent-of(:parent-of(span.apkm-badge:contains("APK")))' <<<"$page1")
        
    [[ "$(pup -p --charset utf-8 ':parent-of(div:contains("noarch"))' <<<"$apks")" == "" ]] || arch=noarch
    [[ "$(pup -p --charset utf-8 ':parent-of(div:contains("universal"))' <<<"$apks")" == "" ]] || arch=universal

    readarray -t apkUrls < <(pup -p --charset utf-8 ":parent-of(div:contains(\"$arch\")) a.accent_color attr{href}" <<<"$apks")

    if [ "$preferSplit" == "true" ]; then
        if [ "${#bundleUrls[@]}" -ne 0 ]; then
            url1=${bundleUrls[-1]}
            appType=bundle
        else
            url1=${apkUrls[-1]}
            appType=apk
        fi
    else
        if [ "${#apkUrls[@]}" -ne 0 ]; then
            url1=${apkUrls[-1]}
            appType=apk
        else
            url1=${bundleUrls[-1]}
            appType=bundle
        fi
    fi  

fi
echo 33

page3=$(curl -sL -A "$UserAgent" "https://www.apkmirror.com$url1")

if [ "$appType" == "bundle" ]; then
    url2=$(pup -p --charset utf-8 'a:contains("Download APK Bundle") attr{href}' <<<"$page3")
else
    url2=$(pup -p --charset utf-8 'a:contains("Download APK") attr{href}' <<<"$page3")
fi
size=$(pup -p --charset utf-8 ':parent-of(:parent-of(svg[alt="APK file size"])) div text{}' <<<"$page3" | sed -n 's/.*(//;s/ bytes.*//;s/,//gp')

[ "$url2" == "" ] && echo error >&2 && exit 1
echo 66

url3=$(curl -sL -A "$UserAgent" "https://www.apkmirror.com$url2" | pup -p --charset UTF-8 'a:contains("here") attr{href}' | head -n 1)

[ "$url3" == "" ] && echo error >&2 && exit 1
echo 100

echo "https://www.apkmirror.com$url3" >&2
echo "$size" >&2
echo "$appType" >&2

# Download the file
wget -q -c "https://www.apkmirror.com$url3" -O "$appName-$appVer.$appType" --show-progress --user-agent="$UserAgent"

if [ "$appType" == "bundle" ]; then
    antiSplitApkm() {
        echo "Reducing app size..."
        splits="splits"
        mkdir -p "$splits"
        unzip -qqo "$appName-$appVer.$appType" -d "$splits"
        rm "$appName-$appVer.$appType"
        appDir="$appName-$appVer"
        mkdir -p "$appDir"
        cp "$splits/base.apk" "$appDir"
        cp "$splits/split_config.${arch//-/_}.apk" "$appDir" 2>/dev/null
        locale=$(locale | grep LANG | cut -d= -f2 | cut -d_ -f1)
        cp "$splits/split_config.${locale}.apk" "$appDir" 2>/dev/null
        cp "$splits"/split_config.*dpi.apk "$appDir" 2>/dev/null
        rm -rf "$splits"
        if command -v java >/dev/null 2>&1 && [ -f "ApkEditor.jar" ]; then
            java -jar ApkEditor.jar m -i "$appDir" -o "$appName-$appVer.apk" 2>/dev/null
            if [ -f "$appName-$appVer.apk" ]; then
                echo "$(du -b "$appName-$appVer.apk" | cut -f1)" > .appSize
            fi
        else
            echo "Java or ApkEditor.jar not found. Skipping APK merging."
        fi
    }
    antiSplitApkm
fi
