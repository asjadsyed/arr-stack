#!/bin/bash

set -euo pipefail
set -x

JELLYFIN_USERNAME="${JELLYFIN_USERNAME}"
JELLYFIN_PASSWORD="${JELLYFIN_PASSWORD}"
JELLYFIN_URL=http://jellyfin:8096
JELLYSEERR_URL=http://jellyseerr:5055
JELLYSEERR_EMAIL="${JELLYSEERR_EMAIL}"
RADARR_URL="http://radarr:7878"
SONARR_URL="http://sonarr:8989"
PROWLARR_URL="http://prowlarr:9696"
RADARR_CATEGORY="movies"
SONARR_CATEGORY="shows"
RADARR_ROOT="/data/media/$RADARR_CATEGORY"
SONARR_ROOT="/data/media/$SONARR_CATEGORY"
RADARR_USERNAME="${RADARR_USERNAME}"
RADARR_PASSWORD="${RADARR_PASSWORD}"
SONARR_USERNAME="${SONARR_USERNAME}"
SONARR_PASSWORD="${SONARR_PASSWORD}"
PROWLARR_USERNAME="${PROWLARR_USERNAME}"
PROWLARR_PASSWORD="${PROWLARR_PASSWORD}"
QBITTORRENT_USERNAME="${QBITTORRENT_USERNAME}"
QBITTORRENT_PASSWORD="${QBITTORRENT_PASSWORD}"
# sleep 10

mkdir -p /data/torrents
mkdir -p /data/torrents/incomplete
chown -R 1000:1000 /data/torrents/

mkdir -p "$RADARR_ROOT"
mkdir -p "$SONARR_ROOT"
# jellyfin | [12:52:54] [WRN] [30] MediaBrowser.Controller.Entities.BaseItem: Library folder /data/media/movies is inaccessible or empty, skipping
# jellyfin | [12:52:54] [WRN] [30] MediaBrowser.Controller.Entities.BaseItem: Library folder /data/media/shows is inaccessible or empty, skipping
touch "$RADARR_ROOT/.gitkeep"
touch "$SONARR_ROOT/.gitkeep"
chown -R 1000:1000 "$RADARR_ROOT"
chown -R 1000:1000 "$SONARR_ROOT"

while [ ! -f /config/jellyseerr-config/settings.json ]; do sleep 2; done
JELLYSEERR_API_KEY=$(jq -r '.main.apiKey' /config/jellyseerr-config/settings.json)

# while [ ! -f /config/prowlarr-config/config.xml ]; do sleep 2; done
# JELLYSEERR_API_KEY=$(jq -r ".main.apiKey" /config/jellyseerr-config/settings.json)
while [ ! -f /config/radarr-config/config.xml ]; do sleep 2; done
RADARR_API_KEY=$(sed -n "s:.*<ApiKey>\\(.*\\)</ApiKey>.*:\\1:p" /config/radarr-config/config.xml)
while [ ! -f /config/sonarr-config/config.xml ]; do sleep 2; done
SONARR_API_KEY=$(sed -n "s:.*<ApiKey>\\(.*\\)</ApiKey>.*:\\1:p" /config/sonarr-config/config.xml)
while [ ! -f /config/prowlarr-config/config.xml ]; do sleep 2; done
PROWLARR_API_KEY=$(sed -n "s:.*<ApiKey>\\(.*\\)</ApiKey>.*:\\1:p" /config/prowlarr-config/config.xml)
echo "JELLYSEERR_API_KEY: $JELLYSEERR_API_KEY"
echo "RADARR_API_KEY: $RADARR_API_KEY"
echo "SONARR_API_KEY: $SONARR_API_KEY"
echo "PROWLARR_API_KEY: $PROWLARR_API_KEY"

# curl -fsS --retry 120 --retry-delay 1 --retry-connrefused "$JELLYFIN_URL/System/Info/Public" >/dev/null
until curl -fsS "$JELLYFIN_URL/health" >/dev/null; do sleep 1; done
until curl -fsS -H "X-Api-Key: $RADARR_API_KEY" "$RADARR_URL/api/v3/system/status" >/dev/null; do sleep 1; done
until curl -fsS -H "X-Api-Key: $SONARR_API_KEY" "$SONARR_URL/api/v3/system/status" >/dev/null; do sleep 1; done
until curl -fsS -H "X-Api-Key: $PROWLARR_API_KEY" "$PROWLARR_URL/api/v1/system/status" >/dev/null; do sleep 1; done

JELLYFIN_STARTUP_WIZARD_COMPLETED=$(sed -n "s:.*<IsStartupWizardCompleted>\\(.*\\)</IsStartupWizardCompleted>.*:\\1:p" /config/jellyfin-config/system.xml)

JELLYFIN_AUTHORIZATION_HEADER='Authorization: MediaBrowser Client="setup", Device="docker", DeviceId="setup-1", Version="10.10.7"'

if [ "$JELLYFIN_STARTUP_WIZARD_COMPLETED" != "true" ]; then
  echo "Jellyfin startup wizard not completed yet; running first-run setup"

  JELLYFIN_CONFIGURATION_PAYLOAD='{"UICulture":"en-US","MetadataCountryCode":"US","PreferredMetadataLanguage":"en"}'
  JELLYFIN_CONFIGURATION_RESPONSE=$(
    curl -fsS "$JELLYFIN_URL/Startup/Configuration" \
      -o /dev/null \
      -X POST \
      -H "$JELLYFIN_AUTHORIZATION_HEADER" \
      -H "Content-Type: application/json" \
      --data-raw "$JELLYFIN_CONFIGURATION_PAYLOAD"
  )

  # GET with side-effects
  JELLYFIN_SET_UP_DEFAULT_USER_RESPONSE=$(
    curl -fsS "$JELLYFIN_URL/Startup/User" \
      -o /dev/null \
      -H "$JELLYFIN_AUTHORIZATION_HEADER"
  )

  JELLYFIN_SET_UP_ADMIN_USER_PAYLOAD=$(jq -n \
    --arg JELLYFIN_USERNAME "$JELLYFIN_USERNAME" \
    --arg JELLYFIN_PASSWORD "$JELLYFIN_PASSWORD" \
  '{
    "Name": $JELLYFIN_USERNAME,
    "Password": $JELLYFIN_PASSWORD
  }')
  JELLYFIN_SET_UP_ADMIN_USER_RESPONSE=$(
    curl -fsS "$JELLYFIN_URL/Startup/User" \
      -X POST \
      -o /dev/null \
      -H "$JELLYFIN_AUTHORIZATION_HEADER" \
      -H "Content-Type: application/json" \
      --data-raw "$JELLYFIN_SET_UP_ADMIN_USER_PAYLOAD"
  )

  JELLYFIN_MOVIES_VALIDATE_PATH_PAYLOAD='{"Path":"/data/media/movies"}'
  JELLYFIN_MOVIES_VALIDATE_PATH_RESPONSE=$(
    curl -fsS "$JELLYFIN_URL/Environment/ValidatePath" \
      -X POST \
      -o /dev/null \
      -H "$JELLYFIN_AUTHORIZATION_HEADER" \
      -H "Content-Type: application/json" \
      --data-raw "$JELLYFIN_MOVIES_VALIDATE_PATH_PAYLOAD"
  )

  JELLYFIN_MOVIES_VIRTUAL_FOLDERS_PAYLOAD='{"LibraryOptions":{"Enabled":true,"EnableArchiveMediaFiles":false,"EnablePhotos":true,"EnableRealtimeMonitor":true,"EnableLUFSScan":true,"ExtractTrickplayImagesDuringLibraryScan":false,"SaveTrickplayWithMedia":false,"EnableTrickplayImageExtraction":false,"ExtractChapterImagesDuringLibraryScan":false,"EnableChapterImageExtraction":false,"EnableInternetProviders":true,"SaveLocalMetadata":false,"EnableAutomaticSeriesGrouping":false,"PreferredMetadataLanguage":"","MetadataCountryCode":"","SeasonZeroDisplayName":"Specials","AutomaticRefreshIntervalDays":0,"EnableEmbeddedTitles":false,"EnableEmbeddedExtrasTitles":false,"EnableEmbeddedEpisodeInfos":false,"AllowEmbeddedSubtitles":"AllowAll","SkipSubtitlesIfEmbeddedSubtitlesPresent":false,"SkipSubtitlesIfAudioTrackMatches":false,"SaveSubtitlesWithMedia":true,"SaveLyricsWithMedia":false,"RequirePerfectSubtitleMatch":true,"AutomaticallyAddToCollection":false,"PreferNonstandardArtistsTag":false,"UseCustomTagDelimiters":false,"MetadataSavers":[],"TypeOptions":[{"Type":"Movie","MetadataFetchers":["TheMovieDb","The Open Movie Database"],"MetadataFetcherOrder":["TheMovieDb","The Open Movie Database"],"ImageFetchers":["TheMovieDb","The Open Movie Database","Embedded Image Extractor","Screen Grabber"],"ImageFetcherOrder":["TheMovieDb","The Open Movie Database","Embedded Image Extractor","Screen Grabber"]}],"LocalMetadataReaderOrder":["Nfo"],"SubtitleDownloadLanguages":[],"CustomTagDelimiters":["/","|",";","\\"],"DelimiterWhitelist":[],"DisabledSubtitleFetchers":[],"SubtitleFetcherOrder":[],"DisabledLyricFetchers":[],"LyricFetcherOrder":[],"PathInfos":[{"Path":"/data/media/movies"}]}}'
  JELLYFIN_MOVIES_VIRTUAL_FOLDERS_RESPONSE=$(
    curl -fsS "$JELLYFIN_URL/Library/VirtualFolders?collectionType=movies&refreshLibrary=false&name=Movies" \
      -X POST \
      -o /dev/null \
      -H "$JELLYFIN_AUTHORIZATION_HEADER" \
      -H "Content-Type: application/json" \
      --data-raw "$JELLYFIN_MOVIES_VIRTUAL_FOLDERS_PAYLOAD"
  )

  JELLYFIN_SHOWS_VALIDATE_PATH_PAYLOAD='{"Path":"/data/media/shows"}'
  JELLYFIN_SHOWS_VALIDATE_PATH_RESPONSE=$(
    curl -fsS "$JELLYFIN_URL/Environment/ValidatePath" \
      -X POST \
      -o /dev/null \
      -H "$JELLYFIN_AUTHORIZATION_HEADER" \
      -H "Content-Type: application/json" \
      --data-raw "$JELLYFIN_SHOWS_VALIDATE_PATH_PAYLOAD"
  )

  JELLYFIN_SHOWS_VIRTUAL_FOLDERS_PAYLOAD='{"LibraryOptions":{"Enabled":true,"EnableArchiveMediaFiles":false,"EnablePhotos":true,"EnableRealtimeMonitor":true,"EnableLUFSScan":true,"ExtractTrickplayImagesDuringLibraryScan":false,"SaveTrickplayWithMedia":false,"EnableTrickplayImageExtraction":false,"ExtractChapterImagesDuringLibraryScan":false,"EnableChapterImageExtraction":false,"EnableInternetProviders":true,"SaveLocalMetadata":false,"EnableAutomaticSeriesGrouping":false,"PreferredMetadataLanguage":"","MetadataCountryCode":"","SeasonZeroDisplayName":"Specials","AutomaticRefreshIntervalDays":0,"EnableEmbeddedTitles":false,"EnableEmbeddedExtrasTitles":false,"EnableEmbeddedEpisodeInfos":false,"AllowEmbeddedSubtitles":"AllowAll","SkipSubtitlesIfEmbeddedSubtitlesPresent":false,"SkipSubtitlesIfAudioTrackMatches":false,"SaveSubtitlesWithMedia":true,"SaveLyricsWithMedia":false,"RequirePerfectSubtitleMatch":true,"AutomaticallyAddToCollection":false,"PreferNonstandardArtistsTag":false,"UseCustomTagDelimiters":false,"MetadataSavers":[],"TypeOptions":[{"Type":"Series","MetadataFetchers":["TheMovieDb","The Open Movie Database"],"MetadataFetcherOrder":["TheMovieDb","The Open Movie Database"],"ImageFetchers":["TheMovieDb"],"ImageFetcherOrder":["TheMovieDb"]},{"Type":"Season","MetadataFetchers":["TheMovieDb"],"MetadataFetcherOrder":["TheMovieDb"],"ImageFetchers":["TheMovieDb"],"ImageFetcherOrder":["TheMovieDb"]},{"Type":"Episode","MetadataFetchers":["TheMovieDb","The Open Movie Database"],"MetadataFetcherOrder":["TheMovieDb","The Open Movie Database"],"ImageFetchers":["TheMovieDb","The Open Movie Database","Embedded Image Extractor","Screen Grabber"],"ImageFetcherOrder":["TheMovieDb","The Open Movie Database","Embedded Image Extractor","Screen Grabber"]}],"LocalMetadataReaderOrder":["Nfo"],"SubtitleDownloadLanguages":[],"CustomTagDelimiters":["/","|",";","\\"],"DelimiterWhitelist":[],"DisabledSubtitleFetchers":[],"SubtitleFetcherOrder":[],"DisabledLyricFetchers":[],"LyricFetcherOrder":[],"PathInfos":[{"Path":"/data/media/shows"}]}}'
  JELLYFIN_SHOWS_VIRTUAL_FOLDERS_RESPONSE=$(
    curl -fsS "$JELLYFIN_URL/Library/VirtualFolders?collectionType=tvshows&refreshLibrary=false&name=Shows" \
      -X POST \
      -o /dev/null \
      -H "$JELLYFIN_AUTHORIZATION_HEADER" \
      -H "Content-Type: application/json" \
      --data-raw "$JELLYFIN_SHOWS_VIRTUAL_FOLDERS_PAYLOAD"
  )

  JELLYFIN_CONFIGURATION_PAYLOAD='{"UICulture":"en-US","MetadataCountryCode":"US","PreferredMetadataLanguage":"en"}'
  JELLYFIN_CONFIGURATION_RESPONSE=$(
    curl -fsS "$JELLYFIN_URL/Startup/Configuration" \
      -o /dev/null \
      -X POST \
      -H "$JELLYFIN_AUTHORIZATION_HEADER" \
      -H "Content-Type: application/json" \
      --data-raw "$JELLYFIN_CONFIGURATION_PAYLOAD"
  )

  JELLYFIN_REMOTE_ACCESS_PAYLOAD='{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}'
  JELLYFIN_REMOTE_ACCESS_RESPONSE=$(
    curl -fsS "$JELLYFIN_URL/Startup/RemoteAccess" \
      -o /dev/null \
      -X POST \
      -H "$JELLYFIN_AUTHORIZATION_HEADER" \
      -H "Content-Type: application/json" \
      --data-raw "$JELLYFIN_REMOTE_ACCESS_PAYLOAD"
  )

  JELLYFIN_COMPLETE_RESPONSE=$(
    curl -fsS "$JELLYFIN_URL/Startup/Complete" \
      -o /dev/null \
      -X POST \
      -H "$JELLYFIN_AUTHORIZATION_HEADER" \
      -H "Content-Length: 0"
  )
else
  echo "Jellyfin startup wizard already completed, skipping..."
fi

# get token and create API keys in Jellyfin for Radarr and Sonarr if they don't already exist

# TOKEN=$(curl -s -X POST "$JELLYFIN_URL/Users/AuthenticateByName" \
#   -H "Content-Type: application/json" \
#   -H "$JELLYFIN_AUTHORIZATION_HEADER" \
#   -d "{\"Username\":\"$JELLYFIN_USERNAME\",\"Pw\":\"$JELLYFIN_PASSWORD\"}" | jq -r .AccessToken)
JELLYFIN_AUTHENTICATE_BY_NAME_PAYLOAD=$(jq -n \
  --arg JELLYFIN_USERNAME "$JELLYFIN_USERNAME" \
  --arg JELLYFIN_PASSWORD "$JELLYFIN_PASSWORD" \
'{
"Username":$JELLYFIN_USERNAME,"Pw":$JELLYFIN_PASSWORD
}'
)
JELLYFIN_AUTHENTICATE_BY_NAME_RESPONSE=$(
  curl -fsS "$JELLYFIN_URL/Users/AuthenticateByName" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "$JELLYFIN_AUTHORIZATION_HEADER" \
    -d "$JELLYFIN_AUTHENTICATE_BY_NAME_PAYLOAD"
)
TOKEN=$(echo "$JELLYFIN_AUTHENTICATE_BY_NAME_RESPONSE" | jq -r .AccessToken)
echo "$TOKEN"

APPS=(
  "Jellyseerr"
  "Radarr"
  "Sonarr"
)

# 3) List keys and create if missing
LIST_KEYS=$(curl -fsS "$JELLYFIN_URL/Auth/Keys" -H "X-Emby-Token: $TOKEN")
declare -A JELLYFIN_API_KEYS
for app in "${APPS[@]}"; do
  echo "$app"
  JELLYFIN_APP_API_KEY=$(echo "$LIST_KEYS" | jq -r --arg app "$app" '.Items[] | select(.AppName==$app) | .AccessToken' | head -n 1)
  if [[ -z "$JELLYFIN_APP_API_KEY" ]]; then
    echo "empty"
    curl -fsS -X POST "$JELLYFIN_URL/Auth/Keys?app=$app" -H "X-Emby-Token: $TOKEN" -o /dev/null
    LIST_KEYS=$(curl -fsS "$JELLYFIN_URL/Auth/Keys" -H "X-Emby-Token: $TOKEN")
    JELLYFIN_APP_API_KEY=$(echo "$LIST_KEYS" | jq -r --arg app "$app" '.Items[] | select(.AppName==$app) | .AccessToken' | head -n 1)
  else
    echo "has value"
  fi
  JELLYFIN_API_KEYS["$app"]="$JELLYFIN_APP_API_KEY"
done

# echo "${JELLYFIN_API_KEYS[@]}"
# for k in "${!JELLYFIN_API_KEYS[@]}"; do
#   echo "$k => ${JELLYFIN_API_KEYS[$k]}"
# done
echo "${JELLYFIN_API_KEYS["Jellyseerr"]}"
echo "${JELLYFIN_API_KEYS["Radarr"]}"
echo "${JELLYFIN_API_KEYS["Sonarr"]}"

# # Use the returned key with:
# #   curl -fsS "$JELLYFIN_URL/Sessions" -H "X-MediaBrowser-Token: <API_KEY>"

# setup jellyseerr

# log jellyseerr into jellyfin

# COOKIE_JAR="/opt/init/jellyseerr.cookies"
COOKIE_JAR="/tmp/jellyseerr.cookies"

JELLYSEERR_AUTH_JELLYFIN_LOGIN_PAYLOAD=$(jq -n \
  --arg JELLYFIN_USERNAME "$JELLYFIN_USERNAME" \
  --arg JELLYFIN_PASSWORD "$JELLYFIN_PASSWORD" \
'{
"username":$JELLYFIN_USERNAME,"password":$JELLYFIN_PASSWORD
}'
)

JELLYSEERR_AUTH_JELLYFIN_BOOTSTRAP_PAYLOAD=$(jq -n \
  --arg JELLYFIN_USERNAME "$JELLYFIN_USERNAME" \
  --arg JELLYFIN_PASSWORD "$JELLYFIN_PASSWORD" \
  --arg JELLYSEERR_EMAIL "$JELLYSEERR_EMAIL" \
'{
"username":$JELLYFIN_USERNAME,"password":$JELLYFIN_PASSWORD,"hostname":"jellyfin","port":8096,"useSsl":false,"urlBase":"","email":$JELLYSEERR_EMAIL,"serverType":2
}'
)

try_auth () {
  local payload="$1"
  curl -fsS "$JELLYSEERR_URL/api/v1/auth/jellyfin" \
    -X POST \
    -c "$COOKIE_JAR" \
    -b "$COOKIE_JAR" \
    -H "Content-Type: application/json" \
    --data-raw "$payload" \
    >/dev/null
}

if try_auth "$JELLYSEERR_AUTH_JELLYFIN_LOGIN_PAYLOAD"; then
  echo "Authenticated via regular login."
elif try_auth "$JELLYSEERR_AUTH_JELLYFIN_BOOTSTRAP_PAYLOAD"; then
  echo "Authenticated via bootstrap."
else
  echo "Authentication failed." >&2
  exit 1
fi

cat "$COOKIE_JAR"

# Set External URL for Jellyfin to localhost:8096 in Jellyseerr settings
JELLYFIN_JELLYSEERR_SETTINGS_PAYLOAD=$(jq -n \
  --arg JELLYFIN_JELLYSEERR_API_KEY "${JELLYFIN_API_KEYS["Jellyseerr"]}" \
'{
  "ip":"jellyfin","port":8096,"useSsl":false,"urlBase":"","externalHostname":"http://localhost:8096","jellyfinForgotPasswordUrl":"","apiKey":$JELLYFIN_JELLYSEERR_API_KEY
}'
)
JELLYFIN_JELLYSEERR_SETTINGS_RESPONSE=$(
    curl -fsS "$JELLYSEERR_URL/api/v1/settings/jellyfin" \
      -X POST \
      -b "$COOKIE_JAR" \
      -H "Content-Type: application/json" \
      --data-raw "$JELLYFIN_JELLYSEERR_SETTINGS_PAYLOAD"
)

# Sync Jellyseerr with Jellyfin libraries
# Jellyseerr Jellyfin Manual Library Scan
PAYLOAD='{"start":true}'
curl -fsS "$JELLYSEERR_URL/api/v1/settings/jellyfin/sync" \
  -X POST \
  -b "$COOKIE_JAR" \
  -H 'Content-Type: application/json' \
  --data-raw "$PAYLOAD"

# LIBRARIES=$(curl -fsS "$JELLYSEERR_URL/api/v1/settings/jellyfin/library?sync=true" \
#   -b "$COOKIE_JAR"
# )
# echo "$LIBRARIES"
# echo "$LIBRARIES" | jq .

# curl -fsS "$JELLYSEERR_URL/api/v1/settings/jellyfin/library?sync=true" -b "$COOKIE_JAR" | jq
LIBRARY_IDS=$(curl -fsS "$JELLYSEERR_URL/api/v1/settings/jellyfin/library?sync=true" -b "$COOKIE_JAR" | jq -r '.[].id' | paste -sd, -)
echo "$LIBRARY_IDS"
curl -fsS "$JELLYSEERR_URL/api/v1/settings/jellyfin/library?sync=true&enable=$LIBRARY_IDS" -b "$COOKIE_JAR"
# exit

# curl -fsS "$JELLYSEERR_URL/api/v1/settings/jellyfin/library?enable=f137a2dd21bbc1b99aa5c0f6bf02a805,a656b907eb3a73532e40e44b968d0225" -b "$COOKIE_JAR"
  
# curl -fsS "$JELLYSEERR_URL/api/v1/settings/jellyfin/library?enable=f137a2dd21bbc1b99aa5c0f6bf02a805" -b "$COOKIE_JAR"

RADARR_EXISTS=$(curl -fsS "$JELLYSEERR_URL/api/v1/settings/radarr" -H "Accept: application/json" -b "$COOKIE_JAR" | jq 'any(.[]; .hostname=="radarr")')
SONARR_EXISTS=$(curl -fsS "$JELLYSEERR_URL/api/v1/settings/sonarr" -H "Accept: application/json" -b "$COOKIE_JAR" | jq 'any(.[]; .hostname=="sonarr")')

if [ "$RADARR_EXISTS" != "true" ]; then
  echo "Setting up Jellyseerr with Radarr..."
  # note: I set "syncEnabled":true
  JELLYSEERR_SETTINGS_RADARR_PAYLOAD=$(jq -n \
    --arg RADARR_API_KEY "$RADARR_API_KEY" \
    --arg RADARR_ROOT "$RADARR_ROOT" \
  '{
  "name":"Radarr","hostname":"radarr","port":7878,"apiKey":$RADARR_API_KEY,"useSsl":false,"baseUrl":"","externalUrl":"http://localhost:7878","activeProfileId":1,"activeProfileName":"Any","activeDirectory":$RADARR_ROOT,"is4k":false,"minimumAvailability":"released","tags":[],"isDefault":true,"syncEnabled":true,"preventSearch":false,"tagRequests":false
  }'
  )
  JELLYSEERR_SETTINGS_RADARR_RESPONSE=$(
    curl -fsS "$JELLYSEERR_URL/api/v1/settings/radarr" \
      -X POST \
      -b "$COOKIE_JAR" \
      -H 'Content-Type: application/json' \
      --data-raw "$JELLYSEERR_SETTINGS_RADARR_PAYLOAD"
  )
else
  echo "Jellyseerr and Radarr already configured, skipping..."
fi

if [ "$SONARR_EXISTS" != "true" ]; then
  echo "Setting up Jellyseerr with Sonarr..."
  JELLYSEERR_SETTINGS_SONARR_PAYLOAD=$(jq -n \
    --arg SONARR_API_KEY "$SONARR_API_KEY" \
    --arg SONARR_ROOT "$SONARR_ROOT" \
  '{
  "name":"Sonarr","hostname":"sonarr","port":8989,"apiKey":$SONARR_API_KEY,"useSsl":false,"baseUrl":"","externalUrl":"http://localhost:8989","activeProfileId":1,"activeProfileName":"Any","activeDirectory":$SONARR_ROOT,"activeAnimeDirectory":"","tags":[],"animeTags":[],"is4k":false,"isDefault":true,"enableSeasonFolders":false,"syncEnabled":true,"preventSearch":false,"tagRequests":false
  }'
  )
  JELLYSEERR_SETTINGS_SONARR_RESPONSE=$(
    curl -fsS "$JELLYSEERR_URL/api/v1/settings/sonarr" \
      -X POST \
      -b "$COOKIE_JAR" \
      -H 'Content-Type: application/json' \
      --data-raw "$JELLYSEERR_SETTINGS_SONARR_PAYLOAD"
  )
else
  echo "Jellyseerr and Sonarr already configured, skipping..."
fi

# initialize
JELLYSEERR_SETTINGS_INITIALIZE_RESPONSE=$(
  curl -fsS "$JELLYSEERR_URL/api/v1/settings/initialize" \
    -X POST \
    -b "$COOKIE_JAR" \
    -H 'Content-Length: 0'
)

# sets the locale apparently
JELLYSEERR_SETTINGS_LOCALE_PAYLOAD='{"locale":"en"}'
curl -fsS "$JELLYSEERR_URL/api/v1/settings/main" \
  -X POST \
  -b "$COOKIE_JAR" \
  -H 'Content-Type: application/json' \
  --data-raw "$JELLYSEERR_SETTINGS_LOCALE_PAYLOAD"





# setup radarr authentication
SETUP_RADARR_AUTHENTICATION_PAYLOAD=$(jq -n \
  --arg RADARR_USERNAME "$RADARR_USERNAME" \
  --arg RADARR_PASSWORD "$RADARR_PASSWORD" \
  --arg RADARR_API_KEY "$RADARR_API_KEY" \
'{
  "bindAddress": "*","port": 7878,"sslPort": 9898,"enableSsl": false,"launchBrowser": true,"authenticationMethod": "forms","authenticationRequired": "enabled","analyticsEnabled": false,"username": $RADARR_USERNAME,"password": $RADARR_PASSWORD,"passwordConfirmation": $RADARR_PASSWORD,"logLevel": "debug","logSizeLimit": 1,"consoleLogLevel": "","branch": "master","apiKey": $RADARR_API_KEY,"sslCertPath": "","sslCertPassword": "","urlBase": "","instanceName": "Radarr","applicationUrl": "","updateAutomatically": false,"updateMechanism": "docker","updateScriptPath": "","proxyEnabled": false,"proxyType": "http","proxyHostname": "","proxyPort": 8080,"proxyUsername": "","proxyPassword": "","proxyBypassFilter": "","proxyBypassLocalAddresses": true,"certificateValidation": "enabled","backupFolder": "Backups","backupInterval": 7,"backupRetention": 28,"trustCgnatIpAddresses": false,"id": 1
}')
SETUP_RADARR_AUTHENTICATION_RESPONSE=$(
  curl -fsS \
    -o /dev/null \
    -X PUT \
    -H "Content-Type: application/json" \
    -H "X-Api-Key: $RADARR_API_KEY" \
    "$RADARR_URL/api/v3/config/host" \
    --data-raw "$SETUP_RADARR_AUTHENTICATION_PAYLOAD"
)

# setup sonarr authentication
SETUP_SONARR_AUTHENTICATION_PAYLOAD=$(jq -n \
  --arg SONARR_USERNAME "$SONARR_USERNAME" \
  --arg SONARR_PASSWORD "$SONARR_PASSWORD" \
  --arg SONARR_API_KEY "$SONARR_API_KEY" \
'{
  "bindAddress":"*","port":8989,"sslPort":9898,"enableSsl":false,"launchBrowser":true,"authenticationMethod":"forms","authenticationRequired":"enabled","analyticsEnabled":false,"username":$SONARR_USERNAME,"password":$SONARR_PASSWORD,"passwordConfirmation":$SONARR_PASSWORD,"logLevel":"debug","logSizeLimit":1,"consoleLogLevel":"","branch":"main","apiKey":$SONARR_API_KEY,"sslCertPath":"","sslCertPassword":"","urlBase":"","instanceName":"Sonarr","applicationUrl":"","updateAutomatically":false,"updateMechanism":"docker","updateScriptPath":"","proxyEnabled":false,"proxyType":"http","proxyHostname":"","proxyPort":8080,"proxyUsername":"","proxyPassword":"","proxyBypassFilter":"","proxyBypassLocalAddresses":true,"certificateValidation":"enabled","backupFolder":"Backups","backupInterval":7,"backupRetention":28,"trustCgnatIpAddresses":false,"id":1
}'
)
SETUP_SONARR_AUTHENTICATION_RESPONSE=$(
  curl -fsS "$SONARR_URL/api/v3/config/host" \
    -o /dev/null \
    -X PUT \
    -H "Content-Type: application/json" \
    -H "X-Api-Key: $SONARR_API_KEY" \
    --data-raw "$SETUP_SONARR_AUTHENTICATION_PAYLOAD"
)

# setup prowlarr authentication
SETUP_PROWLARR_AUTHENTICATION_PAYLOAD=$(jq -n \
  --arg PROWLARR_USERNAME "$PROWLARR_USERNAME" \
  --arg PROWLARR_PASSWORD "$PROWLARR_PASSWORD" \
  --arg PROWLARR_API_KEY "$PROWLARR_API_KEY" \
'{
  "bindAddress":"*","port":9696,"sslPort":6969,"enableSsl":false,"launchBrowser":true,"authenticationMethod":"forms","authenticationRequired":"enabled","analyticsEnabled":true,"username":$PROWLARR_USERNAME,"password":$PROWLARR_PASSWORD,"passwordConfirmation":$PROWLARR_PASSWORD,"logLevel":"debug","logSizeLimit":1,"consoleLogLevel":"","branch":"master","apiKey":$PROWLARR_API_KEY,"sslCertPath":"","sslCertPassword":"","urlBase":"","instanceName":"Prowlarr","applicationUrl":"","updateAutomatically":false,"updateMechanism":"docker","updateScriptPath":"","proxyEnabled":false,"proxyType":"http","proxyHostname":"","proxyPort":8080,"proxyUsername":"","proxyPassword":"","proxyBypassFilter":"","proxyBypassLocalAddresses":true,"certificateValidation":"enabled","backupFolder":"Backups","backupInterval":7,"backupRetention":28,"historyCleanupDays":30,"trustCgnatIpAddresses":false,"id":1
}'
)
SETUP_PROWLARR_AUTHENTICATION_RESPONSE=$(
  curl -fsS "$PROWLARR_URL/api/v1/config/host" \
    -o /dev/null \
    -X PUT \
    -H "Content-Type: application/json" \
    -H "X-Api-Key: $PROWLARR_API_KEY" \
    --data-raw "$SETUP_PROWLARR_AUTHENTICATION_PAYLOAD"
)
# sleep 5

RADARR_IMPORT_EXTRA_FILES_PAYLOAD='{"skipFreeSpaceCheckWhenImporting":false,"minimumFreeSpaceWhenImporting":100,"importExtraFiles":true,"extraFileExtensions":"srt","id":1}'
RADARR_IMPORT_EXTRA_FILES_RESPONSE=$(
  curl -fsS "$RADARR_URL/api/v3/config/mediamanagement" \
    -X PUT \
    -H "Content-Type: application/json" \
    -H "X-Api-Key: $RADARR_API_KEY" \
    --data-raw "$RADARR_IMPORT_EXTRA_FILES_PAYLOAD"
)

SONARR_IMPORT_EXTRA_FILES_PAYLOAD='{"skipFreeSpaceCheckWhenImporting":false,"minimumFreeSpaceWhenImporting":100,"importExtraFiles":true,"extraFileExtensions":"srt","id":1}'
SONARR_IMPORT_EXTRA_FILES_RESPONSE=$(
  curl -fsS "$SONARR_URL/api/v3/config/mediamanagement" \
    -X PUT \
    -H "Content-Type: application/json" \
    -H "X-Api-Key: $SONARR_API_KEY" \
    --data-raw "$SONARR_IMPORT_EXTRA_FILES_PAYLOAD"
)

RADARR_ROOT_FOLDER_REGISTERED=$(
  curl -fsS "$RADARR_URL/api/v3/rootfolder" \
    -H "X-Api-Key: $RADARR_API_KEY" \
  | jq -e --arg RADARR_ROOT "$RADARR_ROOT" '.[] | select(.path == $RADARR_ROOT)' >/dev/null && echo true || echo false
)
if $RADARR_ROOT_FOLDER_REGISTERED; then
  echo "Radarr root folder already registered, skipping..."
else
  echo "Registering Radarr root folder..."
  RADARR_ROOT_FOLDER_PAYLOAD=$(jq -n \
    --arg RADARR_ROOT "$RADARR_ROOT" \
  '{
    "path":$RADARR_ROOT
  }'
  )
  RADARR_ROOT_FOLDER_RESPONSE=$(
    curl -fsS "$RADARR_URL/api/v3/rootfolder" \
      -o /dev/null \
      -H "X-Api-Key: $RADARR_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$RADARR_ROOT_FOLDER_PAYLOAD"
  )
fi

SONARR_ROOT_FOLDER_REGISTERED=$(
  curl -fsS "$SONARR_URL/api/v3/rootfolder" \
    -H "X-Api-Key: $SONARR_API_KEY" \
  | jq -e --arg SONARR_ROOT "$SONARR_ROOT" '.[] | select(.path == $SONARR_ROOT)' >/dev/null && echo true || echo false
)
if $SONARR_ROOT_FOLDER_REGISTERED; then
  echo "Sonarr root folder already registered, skipping..."
else
  echo "Registering Sonarr root folder..."
  SONARR_ROOT_FOLDER_PAYLOAD=$(jq -n \
    --arg SONARR_ROOT "$SONARR_ROOT" \
  '{
    "path":$SONARR_ROOT
  }'
  )
  SONARR_ROOT_FOLDER_RESPONSE=$(
    curl -fsS "$SONARR_URL/api/v3/rootfolder" \
      -o /dev/null \
      -H "X-Api-Key: $SONARR_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$SONARR_ROOT_FOLDER_PAYLOAD"
  )
fi

# sleep 5
RADARR_DOWNLOAD_CLIENT_PAYLOAD=$(jq -n \
  --arg QBITTORRENT_USERNAME "$QBITTORRENT_USERNAME" \
  --arg QBITTORRENT_PASSWORD "$QBITTORRENT_PASSWORD" \
  --arg RADARR_CATEGORY "$RADARR_CATEGORY" \
'{
  "enable": true,
  "protocol": "torrent",
  "priority": 1,
  "removeCompletedDownloads": true,
  "removeFailedDownloads": true,
  "name": "qBittorrent",
  "fields": [
    {"name": "host","value": "qbittorrent"},
    {"name": "port","value": 8080},
    {"name": "useSsl","value": false},
    {"name": "urlBase"},
    {"name": "username","value": $QBITTORRENT_USERNAME},
    {"name": "password","value": $QBITTORRENT_PASSWORD},
    {"name": "movieCategory","value": $RADARR_CATEGORY},
    {"name": "movieImportedCategory"},
    {"name": "recentMoviePriority","value": 0},
    {"name": "olderMoviePriority","value": 0},
    {"name": "initialState","value": 0},
    {"name": "sequentialOrder","value": false},
    {"name": "firstAndLast","value": false},
    {"name": "contentLayout","value": 0}
  ],
  "implementationName": "qBittorrent",
  "implementation": "QBittorrent",
  "configContract": "QBittorrentSettings",
  "infoLink": "https://wiki.servarr.com/radarr/supported#qbittorrent",
  "tags": []
}'
)

RADARR_DOWNLOAD_CLIENT_RESPONSE=$(
  curl -fsS \
    -X POST \
    -H "Content-Type: application/json" \
    -H "X-Api-Key: $RADARR_API_KEY" \
    "$RADARR_URL/api/v3/downloadclient" \
    --data-raw "$RADARR_DOWNLOAD_CLIENT_PAYLOAD"
)

SONARR_DOWNLOAD_CLIENT_PAYLOAD=$(jq -n \
  --arg QBITTORRENT_USERNAME "$QBITTORRENT_USERNAME" \
  --arg QBITTORRENT_PASSWORD "$QBITTORRENT_PASSWORD" \
  --arg SONARR_CATEGORY "$SONARR_CATEGORY" \
'{
  "enable": true,
  "protocol": "torrent",
  "priority": 1,
  "removeCompletedDownloads": true,
  "removeFailedDownloads": true,
  "name": "qBittorrent",
  "fields": [
    {"name": "host","value": "qbittorrent"},
    {"name": "port","value": 8080},
    {"name": "useSsl","value": false},
    {"name": "urlBase"},
    {"name": "username","value": $QBITTORRENT_USERNAME},
    {"name": "password","value": $QBITTORRENT_PASSWORD},
    {"name": "tvCategory","value": $SONARR_CATEGORY},
    {"name": "tvImportedCategory"},
    {"name": "recentTvPriority","value": 0},
    {"name": "olderTvPriority","value": 0},
    {"name": "initialState","value": 0},
    {"name": "sequentialOrder","value": false},
    {"name": "firstAndLast","value": false},
    {"name": "contentLayout","value": 0}
  ],
  "implementationName": "qBittorrent",
  "implementation": "QBittorrent",
  "configContract": "QBittorrentSettings",
  "infoLink": "https://wiki.servarr.com/sonarr/supported#qbittorrent",
  "tags": []
}'
)
SONARR_DOWNLOAD_CLIENT_RESPONSE=$(
  curl -fsS \
    -o /dev/null \
    -X POST \
    -H "Content-Type: application/json" \
    -H "X-Api-Key: $SONARR_API_KEY" \
    "$SONARR_URL/api/v3/downloadclient" \
    --data-raw "$SONARR_DOWNLOAD_CLIENT_PAYLOAD"
)

# Setup Radarr/Sonarr with Prowlarr

PROWLARR_SONARR_PAYLOAD=$(jq -n \
  --arg SONARR_API_KEY "$SONARR_API_KEY" \
'{
    "syncLevel": "fullSync",
    "enable": true,
    "fields": [
        {"name": "prowlarrUrl", "value": "http://prowlarr:9696"},
        {"name": "baseUrl", "value": "http://sonarr:8989"},
        {"name": "apiKey", "value": $SONARR_API_KEY},
        {"name": "syncCategories", "value": [5000,5010,5020,5030,5040,5045,5050,5090]},
        {"name": "animeSyncCategories", "value": [5070]},
        {"name": "syncAnimeStandardFormatSearch", "value": true},
        {"name": "syncRejectBlocklistedTorrentHashesWhileGrabbing", "value": false}
    ],
    "implementationName": "Sonarr",
    "implementation": "Sonarr",
    "configContract": "SonarrSettings",
    "infoLink": "https://wiki.servarr.com/prowlarr/supported#sonarr",
    "tags": [],
    "name": "Sonarr"
}')

PROWLARR_SONARR_ADD_APPLICATION_RESPONSE=$(
  curl -fsS \
    -o /dev/null \
    -X POST \
    -H "Content-Type: application/json" \
    -H "X-Api-Key: $PROWLARR_API_KEY" \
    "$PROWLARR_URL/api/v1/applications" \
    --data-raw "$PROWLARR_SONARR_PAYLOAD"
)

PROWLARR_RADARR_PAYLOAD=$(jq -n \
  --arg RADARR_API_KEY "$RADARR_API_KEY" \
'{
    "syncLevel": "fullSync",
    "enable": true,
    "fields": [
        {"name": "prowlarrUrl", "value": "http://prowlarr:9696"},
        {"name": "baseUrl", "value": "http://radarr:7878"},
        {"name": "apiKey", "value": $RADARR_API_KEY},
        {"name": "syncCategories", "value": [2000,2010,2020,2030,2040,2045,2050,2060,2070,2080,2090]},
        {"name": "syncRejectBlocklistedTorrentHashesWhileGrabbing", "value": false}
    ],
    "implementationName": "Radarr",
    "implementation": "Radarr",
    "configContract": "RadarrSettings",
    "infoLink": "https://wiki.servarr.com/prowlarr/supported#radarr",
    "tags": [],
    "name": "Radarr"
}')

PROWLARR_RADARR_ADD_APPLICATION_RESPONSE=$(
  curl -fsS \
    -o /dev/null \
    -X POST \
    -H "Content-Type: application/json" \
    -H "X-Api-Key: $PROWLARR_API_KEY" \
    "$PROWLARR_URL/api/v1/applications" \
    --data-raw "$PROWLARR_RADARR_PAYLOAD"
)



# echo "${JELLYFIN_API_KEYS["Radarr"]}"
# echo "${JELLYFIN_API_KEYS["Sonarr"]}"
# Jellyfin Radarr/Sonarr API Key is in payload, Use Radarr/Sonarr API Key to send payload to the web app
# Add Jellyfin connection to Radarr
RADARR_ADD_JELLYFIN_CONNECTION_PAYLOAD=$(jq -n \
  --arg JELLYFIN_API_KEY "${JELLYFIN_API_KEYS["Radarr"]}" \
'{
"onGrab":true,"onDownload":true,"onUpgrade":true,"onRename":true,"onMovieAdded":false,"onMovieDelete":true,"onMovieFileDelete":true,"onMovieFileDeleteForUpgrade":true,"onHealthIssue":false,"includeHealthWarnings":false,"onHealthRestored":false,"onApplicationUpdate":true,"onManualInteractionRequired":false,"supportsOnGrab":true,"supportsOnDownload":true,"supportsOnUpgrade":true,"supportsOnRename":true,"supportsOnMovieAdded":false,"supportsOnMovieDelete":true,"supportsOnMovieFileDelete":true,"supportsOnMovieFileDeleteForUpgrade":true,"supportsOnHealthIssue":true,"supportsOnHealthRestored":true,"supportsOnApplicationUpdate":true,"supportsOnManualInteractionRequired":false,"name":"Emby / Jellyfin","fields":[{"name":"host","value":"jellyfin"},{"name":"port","value":8096},{"name":"useSsl","value":false},{"name":"urlBase"},{"name":"apiKey","value":$JELLYFIN_API_KEY},{"name":"notify","value":false},{"name":"updateLibrary","value":true},{"name":"mapFrom"},{"name":"mapTo"}],"implementationName":"Emby / Jellyfin","implementation":"MediaBrowser","configContract":"MediaBrowserSettings","infoLink":"https://wiki.servarr.com/radarr/supported#mediabrowser","tags":[]
}'
)
RADARR_ADD_JELLYFIN_CONNECTION_RESPONSE=""
curl -fsS "$RADARR_URL/api/v3/notification" \
  -o /dev/null \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $RADARR_API_KEY" \
  --data-raw "$RADARR_ADD_JELLYFIN_CONNECTION_PAYLOAD"

# Add Jellyfin connection to Sonarr 
SONARR_ADD_JELLYFIN_CONNECTION_PAYLOAD=$(jq -n \
  --arg JELLYFIN_API_KEY "${JELLYFIN_API_KEYS["Sonarr"]}" \
'{
"onGrab":true,"onDownload":true,"onUpgrade":true,"onImportComplete":true,"onRename":true,"onSeriesAdd":true,"onSeriesDelete":true,"onEpisodeFileDelete":true,"onEpisodeFileDeleteForUpgrade":true,"onHealthIssue":false,"includeHealthWarnings":false,"onHealthRestored":false,"onApplicationUpdate":true,"onManualInteractionRequired":false,"supportsOnGrab":true,"supportsOnDownload":true,"supportsOnUpgrade":true,"supportsOnImportComplete":true,"supportsOnRename":true,"supportsOnSeriesAdd":true,"supportsOnSeriesDelete":true,"supportsOnEpisodeFileDelete":true,"supportsOnEpisodeFileDeleteForUpgrade":true,"supportsOnHealthIssue":true,"supportsOnHealthRestored":true,"supportsOnApplicationUpdate":true,"supportsOnManualInteractionRequired":false,"name":"Emby / Jellyfin","fields":[{"name":"host","value":"jellyfin"},{"name":"port","value":8096},{"name":"useSsl","value":false},{"name":"urlBase"},{"name":"apiKey","value":$JELLYFIN_API_KEY},{"name":"notify","value":false},{"name":"updateLibrary","value":true},{"name":"mapFrom"},{"name":"mapTo"}],"implementationName":"Emby / Jellyfin","implementation":"MediaBrowser","configContract":"MediaBrowserSettings","infoLink":"https://wiki.servarr.com/sonarr/supported#mediabrowser","tags":[]
}'
)
SONARR_ADD_JELLYFIN_CONNECTION_RESPONSE=$(
  curl -fsS "$SONARR_URL/api/v3/notification" \
  -o /dev/null \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $SONARR_API_KEY" \
  --data-raw "$SONARR_ADD_JELLYFIN_CONNECTION_PAYLOAD"
)



# Add Connection - Webhook
# Webhook URL
# http://jellyseerr:5055/api/v1/settings/jobs/radarr-scan/run
# http://jellyseerr:5055/api/v1/settings/jobs/sonarr-scan/run
# http://jellyseerr:5055/api/v1/settings/jobs/jellyfin-recently-added-scan/run
# http://jellyseerr:5055/api/v1/settings/jobs/jellyfin-full-scan/run
# http://jellyseerr:5055/api/v1/webhook/sonarr - ?
# http://jellyseerr:5055/api/v1/webhook/radarr - ?
# http://jellyseerr:5055/api/v1/settings/jobs/download-sync/run
# POST
# Header
# X-Api-Key - $JELLYSEERR_API_KEY



# # radarr
# Radarr Webhook for Jellyseerr to trigger Radarr Scan
## Configure a Radarr webhook to trigger Jellyseerr to rescan Radarr after downloads complete.
# RADARR_JELLYSEERR_RADARR_SCAN_WEBHOOK_PAYLOAD=$(jq -n \
#   --arg JELLYSEERR_API_KEY "$JELLYSEERR_API_KEY" \
# '{
# "onGrab":true,"onDownload":true,"onUpgrade":true,"onRename":true,"onMovieAdded":true,"onMovieDelete":true,"onMovieFileDelete":true,"onMovieFileDeleteForUpgrade":true,"onHealthIssue":false,"includeHealthWarnings":false,"onHealthRestored":false,"onApplicationUpdate":true,"onManualInteractionRequired":true,"supportsOnGrab":true,"supportsOnDownload":true,"supportsOnUpgrade":true,"supportsOnRename":true,"supportsOnMovieAdded":true,"supportsOnMovieDelete":true,"supportsOnMovieFileDelete":true,"supportsOnMovieFileDeleteForUpgrade":true,"supportsOnHealthIssue":true,"supportsOnHealthRestored":true,"supportsOnApplicationUpdate":true,"supportsOnManualInteractionRequired":true,"name":"Jellyseerr Radarr Scan Webhook","fields":[{"name":"url","value":"http://jellyseerr:5055/api/v1/settings/jobs/radarr-scan/run"},{"name":"method","value":1},{"name":"username","value":""},{"name":"password","value":""},{"name":"headers","value":[{"key":"X-Api-Key","value":$JELLYSEERR_API_KEY}]}],"implementationName":"Webhook","implementation":"Webhook","configContract":"WebhookSettings","infoLink":"https://wiki.servarr.com/radarr/supported#webhook","tags":[]
# }'
# )
# RADARR_JELLYSEERR_RADARR_SCAN_WEBHOOK_RESPONSE=$(
#   curl -fsS "$RADARR_URL/api/v3/notification" \
#     -X POST \
#     -H "Content-Type: application/json" \
#     -H "X-Api-Key: $RADARR_API_KEY" \
#     --data-raw "$RADARR_JELLYSEERR_RADARR_SCAN_WEBHOOK_PAYLOAD"
# )


# Radarr Jellyfin Webhook
# # //Configure a Radarr webhook to trigger Jellyseerr to trigger Jellyfin's Recently Added Scan after downloads complete.
# # Configure a Radarr webhook to trigger Jellyseerr's download-sync job after downloads complete, syncing with Jellyseerr with Radarr
# RADARR_JELLYSEERR_JELLYFIN_RECENTLY_ADDED_SCAN_WEBHOOK_PAYLOAD
# RADARR_JELLYSEERR_JELLYFIN_DOWNLOAD_SYNC_WEBHOOK_PAYLOAD=$(ls)

# # sonarr
# Sonarr Webhook for Jellyseerr to trigger Sonarr Scan # download-sync?
# # Configure a Sonarr webhook to trigger Jellyseerr to rescan Sonarr after downloads complete.
# SONARR_JELLYSEERR_SONARR_SCAN_WEBHOOK_PAYLOAD=$(jq -n \
#   --arg JELLYSEERR_API_KEY "$JELLYSEERR_API_KEY" \
# '{
# "onGrab":true,"onDownload":true,"onUpgrade":true,"onImportComplete":true,"onRename":true,"onSeriesAdd":true,"onSeriesDelete":true,"onEpisodeFileDelete":true,"onEpisodeFileDeleteForUpgrade":true,"onHealthIssue":false,"includeHealthWarnings":false,"onHealthRestored":false,"onApplicationUpdate":true,"onManualInteractionRequired":true,"supportsOnGrab":true,"supportsOnDownload":true,"supportsOnUpgrade":true,"supportsOnImportComplete":true,"supportsOnRename":true,"supportsOnSeriesAdd":true,"supportsOnSeriesDelete":true,"supportsOnEpisodeFileDelete":true,"supportsOnEpisodeFileDeleteForUpgrade":true,"supportsOnHealthIssue":true,"supportsOnHealthRestored":true,"supportsOnApplicationUpdate":true,"supportsOnManualInteractionRequired":true,"name":"Jellyseerr Sonarr Scan Webhook","fields":[{"name":"url","value":"http://jellyseerr:5055/api/v1/settings/jobs/sonarr-scan/run"},{"name":"method","value":1},{"name":"username","value":""},{"name":"password","value":""},{"name":"headers","value":[{"key":"X-Api-Key","value":$JELLYSEERR_API_KEY}]}],"implementationName":"Webhook","implementation":"Webhook","configContract":"WebhookSettings","infoLink":"https://wiki.servarr.com/sonarr/supported#webhook","tags":[]
# }'
# )
# SONARR_JELLYSEERR_SONARR_SCAN_WEBHOOK_RESPONSE=$(
#   curl -fsS "$SONARR_URL/api/v3/notification" \
#     -X POST \
#     -H "Content-Type: application/json" \
#     -H "X-Api-Key: $SONARR_API_KEY" \
#     --data-raw "$SONARR_JELLYSEERR_SONARR_SCAN_WEBHOOK_PAYLOAD"
# )

# # Sonarr Jellyfin Webhook
# # Configure a Sonarr webhook to trigger Jellyseerr to trigger Jellyfin's Recently Added Scan after downloads complete.
# SONARR_JELLYSEERR_JELLYFIN_RECENTLY_ADDED_SCAN_WEBHOOK_PAYLOAD=$(jq -n \
#   --arg JELLYSEERR_API_KEY "$JELLYSEERR_API_KEY" \
# '{
# "onGrab":true,"onDownload":true,"onUpgrade":true,"onImportComplete":true,"onRename":true,"onSeriesAdd":true,"onSeriesDelete":true,"onEpisodeFileDelete":true,"onEpisodeFileDeleteForUpgrade":true,"onHealthIssue":false,"includeHealthWarnings":false,"onHealthRestored":false,"onApplicationUpdate":true,"onManualInteractionRequired":true,"supportsOnGrab":true,"supportsOnDownload":true,"supportsOnUpgrade":true,"supportsOnImportComplete":true,"supportsOnRename":true,"supportsOnSeriesAdd":true,"supportsOnSeriesDelete":true,"supportsOnEpisodeFileDelete":true,"supportsOnEpisodeFileDeleteForUpgrade":true,"supportsOnHealthIssue":true,"supportsOnHealthRestored":true,"supportsOnApplicationUpdate":true,"supportsOnManualInteractionRequired":true,"name":"Jellyfin Webhook","fields":[{"name":"url","value":"http://jellyseerr:5055/api/v1/settings/jobs/jellyfin-recently-added-scan/run"},{"name":"method","value":1},{"name":"username","value":""},{"name":"password","value":""},{"name":"headers","value":[{"key":"X-Api-Key","value":$JELLYSEERR_API_KEY}]}],"implementationName":"Webhook","implementation":"Webhook","configContract":"WebhookSettings","infoLink":"https://wiki.servarr.com/sonarr/supported#webhook","tags":[]
# }'
# )
# SONARR_JELLYSEERR_JELLYFIN_RECENTLY_ADDED_SCAN_WEBHOOK_RESPONSE=$(
#   curl -fsS "$SONARR_URL/api/v3/notification" \
#     -X POST \
#     -H "Content-Type: application/json" \
#     -H "X-Api-Key: $SONARR_API_KEY" \
#     --data-raw "$SONARR_JELLYSEERR_JELLYFIN_RECENTLY_ADDED_SCAN_WEBHOOK_PAYLOAD"
# )


# # http://jellyseerr:5055/api/v1/settings/jobs/download-sync/run
# SONARR_JELLYSEERR_DOWNLOAD_SYNC_WEBHOOK_PAYLOAD=$(jq -n \
#   --arg JELLYSEERR_API_KEY "$JELLYSEERR_API_KEY" \
# '{
# "onGrab":true,"onDownload":true,"onUpgrade":true,"onImportComplete":true,"onRename":true,"onSeriesAdd":true,"onSeriesDelete":true,"onEpisodeFileDelete":true,"onEpisodeFileDeleteForUpgrade":true,"onHealthIssue":false,"includeHealthWarnings":false,"onHealthRestored":false,"onApplicationUpdate":true,"onManualInteractionRequired":true,"supportsOnGrab":true,"supportsOnDownload":true,"supportsOnUpgrade":true,"supportsOnImportComplete":true,"supportsOnRename":true,"supportsOnSeriesAdd":true,"supportsOnSeriesDelete":true,"supportsOnEpisodeFileDelete":true,"supportsOnEpisodeFileDeleteForUpgrade":true,"supportsOnHealthIssue":true,"supportsOnHealthRestored":true,"supportsOnApplicationUpdate":true,"supportsOnManualInteractionRequired":true,"name":"Jellyseerr Sonarr Scan Webhook2","fields":[{"name":"url","value":"http://jellyseerr:5055/api/v1/settings/jobs/download-sync/run"},{"name":"method","value":1},{"name":"username","value":""},{"name":"password","value":""},{"name":"headers","value":[{"key":"X-Api-Key","value":$JELLYSEERR_API_KEY}]}],"implementationName":"Webhook","implementation":"Webhook","configContract":"WebhookSettings","infoLink":"https://wiki.servarr.com/sonarr/supported#webhook","tags":[]
# }'
# )
# SONARR_JELLYSEERR_DOWNLOAD_SYNC_WEBHOOK_RESPONSE=$(
#   curl -fsS "$SONARR_URL/api/v3/notification" \
#     -X POST \
#     -H "Content-Type: application/json" \
#     -H "X-Api-Key: $SONARR_API_KEY" \
#     --data-raw "$SONARR_JELLYSEERR_DOWNLOAD_SYNC_WEBHOOK_PAYLOAD"
# )



echo "Starting to add indexers to Prowlarr, disabling xtrace due to noisiness"

set +x

# adding BitSearch to prowlarr
curl -sS "$PROWLARR_URL/api/v1/indexer?" \
  -o /dev/null \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  --data-raw '{"indexerUrls":["https://bitsearch.to/","https://solidtorrents.to/"],"legacyUrls":["https://bitsearch.nocensor.cloud/","https://bitsearch.mrunblock.bond/","https://solidtorrents.net/","https://solidtorrents.nocensor.cloud/","https://solidtorrents.eu/"],"definitionName":"bitsearch","description":"BitSearch (Solid Torrents) is a Public torrent meta-search engine","language":"en-US","enable":true,"redirect":false,"supportsRss":true,"supportsSearch":true,"supportsRedirect":false,"supportsPagination":false,"appProfileId":1,"protocol":"torrent","privacy":"public","capabilities":{"limitsMax":100,"limitsDefault":100,"categories":[{"id":5000,"name":"TV","subCategories":[{"id":5070,"name":"TV/Anime","subCategories":[]}]},{"id":3000,"name":"Audio","subCategories":[{"id":3030,"name":"Audio/Audiobook","subCategories":[]},{"id":3040,"name":"Audio/Lossless","subCategories":[]},{"id":3010,"name":"Audio/MP3","subCategories":[]}]},{"id":7000,"name":"Books","subCategories":[{"id":7020,"name":"Books/EBook","subCategories":[]},{"id":7030,"name":"Books/Comics","subCategories":[]},{"id":7010,"name":"Books/Mags","subCategories":[]}]},{"id":1000,"name":"Console","subCategories":[]},{"id":4000,"name":"PC","subCategories":[{"id":4040,"name":"PC/Mobile-Other","subCategories":[]},{"id":4050,"name":"PC/Games","subCategories":[]},{"id":4070,"name":"PC/Mobile-Android","subCategories":[]},{"id":4020,"name":"PC/ISO","subCategories":[]},{"id":4010,"name":"PC/0day","subCategories":[]},{"id":4030,"name":"PC/Mac","subCategories":[]},{"id":4060,"name":"PC/Mobile-iOS","subCategories":[]}]},{"id":2000,"name":"Movies","subCategories":[]},{"id":8000,"name":"Other","subCategories":[{"id":8010,"name":"Other/Misc","subCategories":[]}]}],"supportsRawSearch":false,"searchParams":["q","q"],"tvSearchParams":["q","season","ep"],"movieSearchParams":["q"],"musicSearchParams":["q"],"bookSearchParams":["q"]},"priority":25,"downloadClientId":0,"added":"0001-01-01T04:57:00Z","sortName":"bitsearch","name":"BitSearch","fields":[{"name":"definitionFile","value":"bitsearch"},{"name":"baseUrl"},{"name":"baseSettings.queryLimit"},{"name":"baseSettings.grabLimit"},{"name":"baseSettings.limitsUnit","value":0},{"name":"torrentBaseSettings.appMinimumSeeders"},{"name":"torrentBaseSettings.seedRatio"},{"name":"torrentBaseSettings.seedTime"},{"name":"torrentBaseSettings.packSeedTime"},{"name":"torrentBaseSettings.preferMagnetUrl","value":false},{"name":"sort","value":0},{"name":"type","value":1}],"implementationName":"Cardigann","implementation":"Cardigann","configContract":"CardigannSettings","infoLink":"https://wiki.servarr.com/prowlarr/supported-indexers#bitsearch","tags":[]}'

# adding kickasstorrents.ws to prowlarr
curl -sS "$PROWLARR_URL/api/v1/indexer" \
  -o /dev/null \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  --data-raw '{"indexerUrls":["https://kickass.ws/","https://kickasstorrents.bz/","https://kkickass.com/","https://kkat.net/","https://kick4ss.com/","https://kickasst.net/","https://kickasstorrents.id/","https://thekat.cc/","https://kattracker.com/"],"legacyUrls":["https://kickass.gg/","https://katcr.io/","https://thekat.nz/","https://thekat.se/","https://kat.how/","https://kat.li/","https://katcr.to/","https://kickasstorrent.cr/","https://kickasstorrents.unblockninja.com/","https://kickass-kat.com/","https://kickass.sh/","https://kickasshydra.dev/"],"definitionName":"kickasstorrents-ws","description":"kickasstorrents.ws is a Public KickAssTorrent clone for MOVIES / TV / GENERAL","language":"en-US","enable":true,"redirect":false,"supportsRss":true,"supportsSearch":true,"supportsRedirect":false,"supportsPagination":false,"appProfileId":1,"protocol":"torrent","privacy":"public","capabilities":{"limitsMax":100,"limitsDefault":100,"categories":[{"id":4000,"name":"PC","subCategories":[]},{"id":7000,"name":"Books","subCategories":[]},{"id":1000,"name":"Console","subCategories":[]},{"id":2000,"name":"Movies","subCategories":[]},{"id":3000,"name":"Audio","subCategories":[]},{"id":8000,"name":"Other","subCategories":[]},{"id":5000,"name":"TV","subCategories":[]},{"id":6000,"name":"XXX","subCategories":[]}],"supportsRawSearch":false,"searchParams":["q","q"],"tvSearchParams":["q","season","ep"],"movieSearchParams":["q"],"musicSearchParams":["q"],"bookSearchParams":["q"]},"priority":25,"downloadClientId":0,"added":"0001-01-01T04:57:00Z","sortName":"kickasstorrents ws","name":"kickasstorrents.ws","fields":[{"name":"definitionFile","value":"kickasstorrents-ws"},{"name":"baseUrl"},{"name":"baseSettings.queryLimit"},{"name":"baseSettings.grabLimit"},{"name":"baseSettings.limitsUnit","value":0},{"name":"torrentBaseSettings.appMinimumSeeders"},{"name":"torrentBaseSettings.seedRatio"},{"name":"torrentBaseSettings.seedTime"},{"name":"torrentBaseSettings.packSeedTime"},{"name":"torrentBaseSettings.preferMagnetUrl","value":false},{"name":"sort","value":2},{"name":"type","value":1}],"implementationName":"Cardigann","implementation":"Cardigann","configContract":"CardigannSettings","infoLink":"https://wiki.servarr.com/prowlarr/supported-indexers#kickasstorrents-ws","tags":[]}'

# adding Knaben to prowlarr
curl -sS "$PROWLARR_URL/api/v1/indexer" \
  -o /dev/null \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  --data-raw '{"indexerUrls":["https://knaben.org/"],"legacyUrls":["https://knaben.eu/"],"definitionName":"Knaben","description":"Knaben is a Public torrent meta-search engine","language":"en-US","encoding":"Unicode (UTF-8)","enable":true,"redirect":false,"supportsRss":true,"supportsSearch":true,"supportsRedirect":false,"supportsPagination":false,"appProfileId":1,"protocol":"torrent","privacy":"public","capabilities":{"limitsMax":100,"limitsDefault":100,"categories":[{"id":3000,"name":"Audio","subCategories":[{"id":3010,"name":"Audio/MP3","subCategories":[]},{"id":3040,"name":"Audio/Lossless","subCategories":[]},{"id":3030,"name":"Audio/Audiobook","subCategories":[]},{"id":3020,"name":"Audio/Video","subCategories":[]},{"id":3050,"name":"Audio/Other","subCategories":[]}]},{"id":1100000,"name":"Audio","subCategories":[]},{"id":1101000,"name":"MP3","subCategories":[]},{"id":1102000,"name":"Lossless","subCategories":[]},{"id":1103000,"name":"Audiobook","subCategories":[]},{"id":1104000,"name":"Audio Video","subCategories":[]},{"id":1105000,"name":"Radio","subCategories":[]},{"id":1106000,"name":"Audio Other","subCategories":[]},{"id":5000,"name":"TV","subCategories":[{"id":5040,"name":"TV/HD","subCategories":[]},{"id":5030,"name":"TV/SD","subCategories":[]},{"id":5045,"name":"TV/UHD","subCategories":[]},{"id":5080,"name":"TV/Documentary","subCategories":[]},{"id":5020,"name":"TV/Foreign","subCategories":[]},{"id":5060,"name":"TV/Sport","subCategories":[]},{"id":5050,"name":"TV/Other","subCategories":[]},{"id":5070,"name":"TV/Anime","subCategories":[]}]},{"id":2100000,"name":"TV","subCategories":[]},{"id":2101000,"name":"TV HD","subCategories":[]},{"id":2102000,"name":"TV SD","subCategories":[]},{"id":2103000,"name":"TV UHD","subCategories":[]},{"id":2104000,"name":"Documentary","subCategories":[]},{"id":2105000,"name":"TV Foreign","subCategories":[]},{"id":2106000,"name":"Sport","subCategories":[]},{"id":2107000,"name":"Cartoon","subCategories":[]},{"id":2108000,"name":"TV Other","subCategories":[]},{"id":2000,"name":"Movies","subCategories":[{"id":2040,"name":"Movies/HD","subCategories":[]},{"id":2030,"name":"Movies/SD","subCategories":[]},{"id":2045,"name":"Movies/UHD","subCategories":[]},{"id":2070,"name":"Movies/DVD","subCategories":[]},{"id":2010,"name":"Movies/Foreign","subCategories":[]},{"id":2060,"name":"Movies/3D","subCategories":[]},{"id":2020,"name":"Movies/Other","subCategories":[]}]},{"id":3100000,"name":"Movies","subCategories":[]},{"id":3101000,"name":"Movies HD","subCategories":[]},{"id":3102000,"name":"Movies SD","subCategories":[]},{"id":3103000,"name":"Movies UHD","subCategories":[]},{"id":3104000,"name":"Movies DVD","subCategories":[]},{"id":3105000,"name":"Movies Foreign","subCategories":[]},{"id":3106000,"name":"Movies Bollywood","subCategories":[]},{"id":3107000,"name":"Movies 3D","subCategories":[]},{"id":3108000,"name":"Movies Other","subCategories":[]},{"id":4000,"name":"PC","subCategories":[{"id":4050,"name":"PC/Games","subCategories":[]},{"id":4010,"name":"PC/0day","subCategories":[]},{"id":4030,"name":"PC/Mac","subCategories":[]},{"id":4020,"name":"PC/ISO","subCategories":[]},{"id":4040,"name":"PC/Mobile-Other","subCategories":[]},{"id":4070,"name":"PC/Mobile-Android","subCategories":[]},{"id":4060,"name":"PC/Mobile-iOS","subCategories":[]}]},{"id":4100000,"name":"PC","subCategories":[]},{"id":4101000,"name":"Games","subCategories":[]},{"id":4102000,"name":"Software","subCategories":[]},{"id":4103000,"name":"Mac","subCategories":[]},{"id":4104000,"name":"Unix","subCategories":[]},{"id":6000,"name":"XXX","subCategories":[{"id":6040,"name":"XXX/x264","subCategories":[]},{"id":6060,"name":"XXX/ImageSet","subCategories":[]},{"id":6070,"name":"XXX/Other","subCategories":[]}]},{"id":5100000,"name":"XXX","subCategories":[]},{"id":5101000,"name":"XXX Video","subCategories":[]},{"id":5102000,"name":"XXX ImageSet","subCategories":[]},{"id":5103000,"name":"XXX Games","subCategories":[]},{"id":5104000,"name":"XXX Hentai","subCategories":[]},{"id":5105000,"name":"XXX Other","subCategories":[]},{"id":6100000,"name":"Anime","subCategories":[]},{"id":6101000,"name":"Anime Subbed","subCategories":[]},{"id":6102000,"name":"Anime Dubbed","subCategories":[]},{"id":6103000,"name":"Anime Dual audio","subCategories":[]},{"id":6104000,"name":"Anime Raw","subCategories":[]},{"id":6105000,"name":"Music Video","subCategories":[]},{"id":7000,"name":"Books","subCategories":[{"id":7050,"name":"Books/Other","subCategories":[]},{"id":7020,"name":"Books/EBook","subCategories":[]},{"id":7030,"name":"Books/Comics","subCategories":[]},{"id":7010,"name":"Books/Mags","subCategories":[]},{"id":7040,"name":"Books/Technical","subCategories":[]}]},{"id":6106000,"name":"Literature","subCategories":[]},{"id":6107000,"name":"Music","subCategories":[]},{"id":6108000,"name":"Anime non-english translated","subCategories":[]},{"id":1000,"name":"Console","subCategories":[{"id":1180,"name":"Console/PS4","subCategories":[]},{"id":1080,"name":"Console/PS3","subCategories":[]},{"id":1120,"name":"Console/PS Vita","subCategories":[]},{"id":1020,"name":"Console/PSP","subCategories":[]},{"id":1050,"name":"Console/XBox 360","subCategories":[]},{"id":1040,"name":"Console/XBox","subCategories":[]},{"id":1010,"name":"Console/NDS","subCategories":[]},{"id":1030,"name":"Console/Wii","subCategories":[]},{"id":1130,"name":"Console/WiiU","subCategories":[]},{"id":1110,"name":"Console/3DS","subCategories":[]},{"id":1090,"name":"Console/Other","subCategories":[]}]},{"id":7100000,"name":"Console","subCategories":[]},{"id":7101000,"name":"PS4","subCategories":[]},{"id":7102000,"name":"PS3","subCategories":[]},{"id":7103000,"name":"PS2","subCategories":[]},{"id":7104000,"name":"PS1","subCategories":[]},{"id":7105000,"name":"PS Vita","subCategories":[]},{"id":7106000,"name":"PSP","subCategories":[]},{"id":7107000,"name":"Xbox 360","subCategories":[]},{"id":7108000,"name":"Xbox","subCategories":[]},{"id":7109000,"name":"Switch","subCategories":[]},{"id":7110000,"name":"NDS","subCategories":[]},{"id":7111000,"name":"Wii","subCategories":[]},{"id":7112000,"name":"WiiU","subCategories":[]},{"id":7113000,"name":"3DS","subCategories":[]},{"id":7114000,"name":"GameCube","subCategories":[]},{"id":7115000,"name":"Other","subCategories":[]},{"id":8100000,"name":"Mobile","subCategories":[]},{"id":8101000,"name":"Android","subCategories":[]},{"id":8102000,"name":"IOS","subCategories":[]},{"id":8103000,"name":"PC Other","subCategories":[]},{"id":9100000,"name":"Books","subCategories":[]},{"id":9101000,"name":"EBooks","subCategories":[]},{"id":9102000,"name":"Comics","subCategories":[]},{"id":9103000,"name":"Magazines","subCategories":[]},{"id":9104000,"name":"Technical","subCategories":[]},{"id":9105000,"name":"Books Other","subCategories":[]},{"id":8000,"name":"Other","subCategories":[{"id":8010,"name":"Other/Misc","subCategories":[]}]},{"id":10100000,"name":"Other","subCategories":[]},{"id":10101000,"name":"Other Misc","subCategories":[]}],"supportsRawSearch":false,"searchParams":["q"],"tvSearchParams":["q","season","ep"],"movieSearchParams":["q"],"musicSearchParams":["q"],"bookSearchParams":["q"]},"priority":25,"downloadClientId":0,"added":"0001-01-01T04:57:00Z","sortName":"knaben","name":"Knaben","fields":[{"name":"baseUrl"},{"name":"baseSettings.queryLimit"},{"name":"baseSettings.grabLimit"},{"name":"baseSettings.limitsUnit","value":0},{"name":"torrentBaseSettings.appMinimumSeeders"},{"name":"torrentBaseSettings.seedRatio"},{"name":"torrentBaseSettings.seedTime"},{"name":"torrentBaseSettings.packSeedTime"},{"name":"torrentBaseSettings.preferMagnetUrl","value":false}],"implementationName":"Knaben","implementation":"Knaben","configContract":"NoAuthTorrentBaseSettings","infoLink":"https://wiki.servarr.com/prowlarr/supported-indexers#knaben","tags":[]}'

# adding limetorrents to prowlarr
curl -sS "$PROWLARR_URL/api/v1/indexer" \
  -o /dev/null \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  --data-raw $'{"indexerUrls":["https://www.limetorrents.fun/","https://limetorrents.unblockninja.com/","https://limetorrents.ninjaproxy1.com/","https://limetorrents.proxyninja.org/","https://limetorrents.proxyninja.net/","https://limetorrents.torrentbay.st/","https://limetorrents.torrentsbay.org/"],"legacyUrls":["https://limetorrents.mrunblock.bond/","https://limetorrents.nocensor.cloud/","https://limetorrents.abcproxy.org/","https://limetorrents.unblockit.download/","https://www.limetorrents.lol/"],"definitionName":"limetorrents","description":"LimeTorrents is a Public general torrent index with mostly verified torrents","language":"en-US","enable":true,"redirect":false,"supportsRss":true,"supportsSearch":true,"supportsRedirect":false,"supportsPagination":false,"appProfileId":1,"protocol":"torrent","privacy":"public","capabilities":{"limitsMax":100,"limitsDefault":100,"categories":[{"id":5000,"name":"TV","subCategories":[{"id":5070,"name":"TV/Anime","subCategories":[]}]},{"id":2000,"name":"Movies","subCategories":[]},{"id":3000,"name":"Audio","subCategories":[]},{"id":1000,"name":"Console","subCategories":[]},{"id":4000,"name":"PC","subCategories":[{"id":4010,"name":"PC/0day","subCategories":[]}]},{"id":8000,"name":"Other","subCategories":[]},{"id":7000,"name":"Books","subCategories":[{"id":7020,"name":"Books/EBook","subCategories":[]}]}],"supportsRawSearch":false,"searchParams":["q","q"],"tvSearchParams":["q","season","ep"],"movieSearchParams":["q"],"musicSearchParams":["q"],"bookSearchParams":["q"]},"priority":25,"downloadClientId":0,"added":"0001-01-01T04:57:00Z","sortName":"limetorrents","name":"LimeTorrents","fields":[{"name":"definitionFile","value":"limetorrents"},{"name":"baseUrl"},{"name":"baseSettings.queryLimit"},{"name":"baseSettings.grabLimit"},{"name":"baseSettings.limitsUnit","value":0},{"name":"torrentBaseSettings.appMinimumSeeders"},{"name":"torrentBaseSettings.seedRatio"},{"name":"torrentBaseSettings.seedTime"},{"name":"torrentBaseSettings.packSeedTime"},{"name":"torrentBaseSettings.preferMagnetUrl","value":false},{"name":"downloadlink","value":1},{"name":"downloadlink2","value":0},{"name":"info_download","value":"As the .torrent download links on this site are known to fail from time to time, you can optionally set as a fallback an automatic alternate link."},{"name":"sort","value":0},{"name":"info_category_8000","value":"LimeTorrents only returns category <b>Other</b> in its <i>Keywordless</i> search results page.</br>To pass your apps\' indexer TEST you will need to include the 8000(Other) category."}],"implementationName":"Cardigann","implementation":"Cardigann","configContract":"CardigannSettings","infoLink":"https://wiki.servarr.com/prowlarr/supported-indexers#limetorrents","tags":[]}'

# adding The Pirate Bay to prowlarr
curl -sS "$PROWLARR_URL/api/v1/indexer" \
  -o /dev/null \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  --data-raw $'{"indexerUrls":["https://thepiratebay.org/","https://thepiratebay.unblockninja.com/","https://thepiratebay.ninjaproxy1.com/","https://tpb.proxyninja.org/","https://thepiratebay.proxyninja.net/","https://thepiratebay.torrentbay.st/","https://tpb.skynetcloud.site/","https://piratehaven.xyz/","https://mirrorbay.top/","https://thepiratebay0.org/","https://thepiratebay10.xyz/","https://pirateproxylive.org/","https://thehiddenbay.com/","https://thepiratebay.zone/","https://tpb.party/","https://piratebayproxy.live/","https://piratebay.live/","https://piratebay.party/","https://thepiratebay.party/","https://thepiratebaye.org/","https://thepiratebay.cloud/","https://tpb-proxy.xyz/","https://tpb.re/","https://tpirbay.site/","https://tpirbay.top/","https://tpirbay.xyz/"],"legacyUrls":["https://pirate-proxy.page/","https://5mins.shop/","https://tpb.surf/","https://tpb.monster/","https://thepiratebay.host/","https://piratetoday.xyz/","https://tpb.wtf/","https://piratebayo3klnzokct3wt5yyxb2vpebbuyjl7m623iaxmqhsd52coid.onion.ly/","https://piratebayo3klnzokct3wt5yyxb2vpebbuyjl7m623iaxmqhsd52coid.tor2web.to/","https://piratebayo3klnzokct3wt5yyxb2vpebbuyjl7m623iaxmqhsd52coid.tor2web.link/","https://tpb25.ukpass.co/","https://tpb29.ukpass.co/","https://piratenow.xyz/","https://pirate-proxy.ink/","https://proxifiedpiratebay.org/","https://unlockedpiratebay.com/","https://tpb.one/","https://piratebayorg.net/","https://tpbproxy.click/","https://pirateproxy.live/","https://ukpiratebay.org/","https://piratebay.by/","https://pirate-proxy.date/","https://thepirateproxy.net/","https://thepiratebay.abcproxy.org/","https://tpb.proxyninja.net/","https://tpb31.ukpass.co/","https://thepiratebay10.org/","https://pirate-proxy.africa/","https://5mins.eu/","https://piratebay.army/","https://tpb-visit.me/","https://pirate-proxy.ong/"],"definitionName":"thepiratebay","description":"The Pirate Bay (TPB) is the galaxy\u2019s most resilient Public BitTorrent site","language":"en-US","enable":true,"redirect":false,"supportsRss":true,"supportsSearch":true,"supportsRedirect":false,"supportsPagination":false,"appProfileId":1,"protocol":"torrent","privacy":"public","capabilities":{"limitsMax":100,"limitsDefault":100,"categories":[{"id":3000,"name":"Audio","subCategories":[{"id":3030,"name":"Audio/Audiobook","subCategories":[]},{"id":3040,"name":"Audio/Lossless","subCategories":[]},{"id":3050,"name":"Audio/Other","subCategories":[]},{"id":3020,"name":"Audio/Video","subCategories":[]}]},{"id":2000,"name":"Movies","subCategories":[{"id":2020,"name":"Movies/Other","subCategories":[]},{"id":2040,"name":"Movies/HD","subCategories":[]},{"id":2060,"name":"Movies/3D","subCategories":[]},{"id":2030,"name":"Movies/SD","subCategories":[]},{"id":2045,"name":"Movies/UHD","subCategories":[]}]},{"id":5000,"name":"TV","subCategories":[{"id":5050,"name":"TV/Other","subCategories":[]},{"id":5040,"name":"TV/HD","subCategories":[]},{"id":5045,"name":"TV/UHD","subCategories":[]}]},{"id":4000,"name":"PC","subCategories":[{"id":4030,"name":"PC/Mac","subCategories":[]},{"id":4040,"name":"PC/Mobile-Other","subCategories":[]},{"id":4060,"name":"PC/Mobile-iOS","subCategories":[]},{"id":4070,"name":"PC/Mobile-Android","subCategories":[]},{"id":4050,"name":"PC/Games","subCategories":[]}]},{"id":1000,"name":"Console","subCategories":[{"id":1180,"name":"Console/PS4","subCategories":[]},{"id":1040,"name":"Console/XBox","subCategories":[]},{"id":1030,"name":"Console/Wii","subCategories":[]},{"id":1090,"name":"Console/Other","subCategories":[]}]},{"id":6000,"name":"XXX","subCategories":[{"id":6010,"name":"XXX/DVD","subCategories":[]},{"id":6060,"name":"XXX/ImageSet","subCategories":[]},{"id":6040,"name":"XXX/x264","subCategories":[]},{"id":6045,"name":"XXX/UHD","subCategories":[]},{"id":6070,"name":"XXX/Other","subCategories":[]}]},{"id":8000,"name":"Other","subCategories":[]},{"id":7000,"name":"Books","subCategories":[{"id":7020,"name":"Books/EBook","subCategories":[]},{"id":7030,"name":"Books/Comics","subCategories":[]},{"id":7050,"name":"Books/Other","subCategories":[]}]}],"supportsRawSearch":false,"searchParams":["q","q"],"tvSearchParams":["q","season","ep"],"movieSearchParams":["q"],"musicSearchParams":["q"],"bookSearchParams":["q"]},"priority":25,"downloadClientId":0,"added":"0001-01-01T04:57:00Z","sortName":"pirate bay","name":"The Pirate Bay","fields":[{"name":"definitionFile","value":"thepiratebay"},{"name":"baseUrl"},{"name":"baseSettings.queryLimit"},{"name":"baseSettings.grabLimit"},{"name":"baseSettings.limitsUnit","value":0},{"name":"torrentBaseSettings.appMinimumSeeders"},{"name":"torrentBaseSettings.seedRatio"},{"name":"torrentBaseSettings.seedTime"},{"name":"torrentBaseSettings.packSeedTime"},{"name":"torrentBaseSettings.preferMagnetUrl","value":false},{"name":"uploader"},{"name":"info_uploader","value":"You can filter by Uploader by entering a Case Sensitive username, or leave empty to get all results.<br>Note: this is the username of the Uploader and not the Groupname that often show up at the end of TPB titles, eg -MeGusta."},{"name":"info_api","value":"This indexer uses the API at https://apibay.org/ to get its official TPB data. Choose any site link that you can access/prefer so that you can view the torrent details page when browsing the search results for this indexer."}],"implementationName":"Cardigann","implementation":"Cardigann","configContract":"CardigannSettings","infoLink":"https://wiki.servarr.com/prowlarr/supported-indexers#thepiratebay","tags":[]}'

# adding TorrentDownload to prowlarr
curl -sS "$PROWLARR_URL/api/v1/indexer" \
  -o /dev/null \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  --data-raw '{"indexerUrls":["https://www.torrentdownload.info/"],"legacyUrls":["https://torrentdownload.mrunblock.bond/","https://torrentdownload.nocensor.cloud/","https://torrentdownload.unblockit.download/"],"definitionName":"torrentdownload","description":"TorrentDownload is a Public torrent meta-search engine","language":"en-US","enable":true,"redirect":false,"supportsRss":true,"supportsSearch":true,"supportsRedirect":false,"supportsPagination":false,"appProfileId":1,"protocol":"torrent","privacy":"public","capabilities":{"limitsMax":100,"limitsDefault":100,"categories":[{"id":6000,"name":"XXX","subCategories":[]},{"id":5000,"name":"TV","subCategories":[{"id":5070,"name":"TV/Anime","subCategories":[]},{"id":5080,"name":"TV/Documentary","subCategories":[]},{"id":5050,"name":"TV/Other","subCategories":[]}]},{"id":4000,"name":"PC","subCategories":[{"id":4010,"name":"PC/0day","subCategories":[]},{"id":4070,"name":"PC/Mobile-Android","subCategories":[]},{"id":4050,"name":"PC/Games","subCategories":[]}]},{"id":3000,"name":"Audio","subCategories":[{"id":3030,"name":"Audio/Audiobook","subCategories":[]},{"id":3040,"name":"Audio/Lossless","subCategories":[]},{"id":3010,"name":"Audio/MP3","subCategories":[]},{"id":3020,"name":"Audio/Video","subCategories":[]}]},{"id":7000,"name":"Books","subCategories":[{"id":7030,"name":"Books/Comics","subCategories":[]},{"id":7020,"name":"Books/EBook","subCategories":[]},{"id":7010,"name":"Books/Mags","subCategories":[]}]},{"id":1000,"name":"Console","subCategories":[]},{"id":2000,"name":"Movies","subCategories":[]},{"id":8000,"name":"Other","subCategories":[{"id":8010,"name":"Other/Misc","subCategories":[]}]}],"supportsRawSearch":false,"searchParams":["q","q"],"tvSearchParams":["q","season","ep"],"movieSearchParams":["q"],"musicSearchParams":["q"],"bookSearchParams":["q"]},"priority":25,"downloadClientId":0,"added":"0001-01-01T04:57:00Z","sortName":"torrentdownload","name":"TorrentDownload","fields":[{"name":"definitionFile","value":"torrentdownload"},{"name":"baseUrl"},{"name":"baseSettings.queryLimit"},{"name":"baseSettings.grabLimit"},{"name":"baseSettings.limitsUnit","value":0},{"name":"torrentBaseSettings.appMinimumSeeders"},{"name":"torrentBaseSettings.seedRatio"},{"name":"torrentBaseSettings.seedTime"},{"name":"torrentBaseSettings.packSeedTime"},{"name":"torrentBaseSettings.preferMagnetUrl","value":false},{"name":"sort","value":1}],"implementationName":"Cardigann","implementation":"Cardigann","configContract":"CardigannSettings","infoLink":"https://wiki.servarr.com/prowlarr/supported-indexers#torrentdownload","tags":[]}'

# adding TorrentGalaxyClone
curl -sS "$PROWLARR_URL/api/v1/indexer" \
  -o /dev/null \
  -X POST \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: $PROWLARR_API_KEY" \
  --data-raw '{"indexerUrls":["https://torrentgalaxy.one/","https://torrentgalaxy.info/","https://torrentgalaxy.space/"],"legacyUrls":[],"definitionName":"torrentgalaxyclone","description":"TorrentGalaxyClone is a Public site for MOVIES / TV / GENERAL","language":"en-US","enable":true,"redirect":false,"supportsRss":true,"supportsSearch":true,"supportsRedirect":false,"supportsPagination":false,"appProfileId":1,"protocol":"torrent","privacy":"public","capabilities":{"limitsMax":100,"limitsDefault":100,"categories":[{"id":5000,"name":"TV","subCategories":[{"id":5070,"name":"TV/Anime","subCategories":[]},{"id":5080,"name":"TV/Documentary","subCategories":[]}]},{"id":4000,"name":"PC","subCategories":[]},{"id":7000,"name":"Books","subCategories":[]},{"id":1000,"name":"Console","subCategories":[]},{"id":2000,"name":"Movies","subCategories":[]},{"id":3000,"name":"Audio","subCategories":[]},{"id":8000,"name":"Other","subCategories":[]},{"id":6000,"name":"XXX","subCategories":[]}],"supportsRawSearch":false,"searchParams":["q","q"],"tvSearchParams":["q","season","ep","imdbId"],"movieSearchParams":["q","imdbId"],"musicSearchParams":["q"],"bookSearchParams":["q"]},"priority":25,"downloadClientId":0,"added":"0001-01-01T04:57:00Z","sortName":"torrentgalaxyclone","name":"TorrentGalaxyClone","fields":[{"name":"definitionFile","value":"torrentgalaxyclone"},{"name":"baseUrl"},{"name":"baseSettings.queryLimit"},{"name":"baseSettings.grabLimit"},{"name":"baseSettings.limitsUnit","value":0},{"name":"torrentBaseSettings.appMinimumSeeders"},{"name":"torrentBaseSettings.seedRatio"},{"name":"torrentBaseSettings.seedTime"},{"name":"torrentBaseSettings.packSeedTime"},{"name":"torrentBaseSettings.preferMagnetUrl","value":false},{"name":"uploader"},{"name":"info_uploader","value":"You can filter by Uploader by entering a Case Sensitive username, or leave empty to get all results.<br>Note: this is the username of the Uploader and not the Groupname that often show up at the end of TGx titles, eg RMTeam."}],"implementationName":"Cardigann","implementation":"Cardigann","configContract":"CardigannSettings","infoLink":"https://wiki.servarr.com/prowlarr/supported-indexers#torrentgalaxyclone","tags":[]}'

set -x

echo "Done adding indexers to Prowlarr, re-enabling xtrace"

echo "Finished init"
# sleep to allow docker exec'ing into for debugging
sleep 10000000000000000000
