#!/bin/bash
source utils.sh

repo1="$GITHUB_REPOSITORY"
repo2="inotia00/revanced-patches"
time_threshold=24

current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

response1=$(wget --spider -S "https://api.github.com/repos/$repo1/releases/latest" 2>&1 | grep "HTTP/" | awk '{print $2}')
if [[ $response1 -eq 404 ]]; then
    patch_ytrv
else
    response2=$(wget --spider -S "https://api.github.com/repos/$repo2/releases/latest" 2>&1 | grep "HTTP/" | awk '{print $2}')
    if [[ $response2 -eq 200 ]]; then
        assets=$(wget -qO- "https://api.github.com/repos/$repo2/releases/latest" | jq -r '.assets')
        if [[ $assets ]]; then
            asset=$(echo "$assets" | jq -r '.[0]')
            published_at=$(echo "$asset" | jq -r '.updated_at')
            published_time=$(date -u -d "$published_at" +"%Y-%m-%dT%H:%M:%SZ")
            difference=$(( ($(date -u -d "$current_time" +"%s") - $(date -u -d "$published_time" +"%s")) / 3600 ))
            if [[ $difference -le $time_threshold ]]; then
                patch_ytrv
            else
                echo "Skipping patch"
            fi
        else
            echo "Skipping patch"
        fi
    else
        echo "Skipping patch "
    fi
fi
