#!/bin/bash

req() {
    wget -nv -O "$2" -U "Mozilla/5.0 (X11; Linux x86_64; rv:111.0) Gecko/20100101 Firefox/111.0" "$1"
}

dl_gh() {
    for repo in revanced-patches revanced-cli revanced-integrations; do
        api_url="https://api.github.com/repos/inotia00/$repo/releases/latest"
        asset_urls=($(wget -qO- "$api_url" | jq -r '.assets[] | "\(.browser_download_url) \(.name)"'))        
        for ((i = 0; i < ${#asset_urls[@]}; i += 2)); do
            req "${asset_urls[i]}" "${asset_urls[i+1]}"
        done
    done
}

get_patches_key() {
    dl_yt
    mapfile -t patches < "patches.txt" 
    for line in "${patches[@]}"; do
        if [[ -n "$line" && ( ${line:0:1} == "+" || ${line:0:1} == "-" ) ]]; then
            patch_name=$(sed -e 's/^[+|-] *//;s/ *$//' <<< "$line") 
            [[ ${line:0:1} == "+" ]] && include_patches+=("--include" "$patch_name")
            [[ ${line:0:1} == "-" ]] && exclude_patches+=("--exclude" "$patch_name")
        fi
    done
}

dl_yt() {
    get_version
    base_url="https://www.apkmirror.com"
    url="$base_url/apk/google-inc/youtube/youtube-${version//./-}-release/"
    url="$base_url$(req "$url" - | tr '\n' ' ' | sed -n "s/href=\"/@/g; s;.*APK</span>[^@]*@\([^#]*\).*;\1;p")"
    url="$base_url$(req "$url" - | grep "downloadButton" | sed -n 's;.*href="\(.*key=[^"]*\)">.*;\1;p')"
    url="$base_url$(req "$url" - | grep "please click" | sed -n 's#.*href="\(.*key=[^"]*\)">.*#\1#;s#amp;##p')&forcebaseapk=true"
    req "$url" "youtube-v${version}.apk"
}
get_version() {
    dl_gh
    version=$(jq -r '
        .. 
        | objects 
        | select(.name == "com.google.android.youtube" 
        and .versions != null) 
        | .versions[]' patches.json \
        | sort -ur \
        | sed -n '1p' # use 1,2,3 to choose lower version
    )
}

patch_ytrv() {
    get_patches_key
    declare -a patch_args=(
        -jar revanced-cli*.jar patch
        --merge revanced-integrations*.apk
        --patch-bundle revanced-patches*.jar
        --out /tmp/patched_output.apk
        youtube-v${version}.apk
        --options options.json
        --rip-lib x86_64
        --rip-lib x86
        "${exclude_patches[@]}"
        "${include_patches[@]}"
    )
    declare -a sign_args=(
        --ks public.jks
        --ks-key-alias public
        --ks-pass pass:public
        --key-pass pass:public
        --in /tmp/patched_output.apk
        --out ./youtube-extended-v$version.apk
    )
    java "${patch_args[@]}"
    apksigner="$(find $ANDROID_SDK_ROOT/build-tools -name apksigner | sort -r | head -n 1)"
    "$apksigner" sign "${sign_args[@]}"
    rm /tmp/patched_output.apk
}
