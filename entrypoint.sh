#!/bin/sh

set -eu

: ${MOPIDY_HTTP_ALLOWED_ORIGINS:=https://${HOSTNAME},https://${HOSTNAME}:8443}
: ${MOPIDY_IRIS_SNAPCAST_HOST:=$HOSTNAME}
: ${MOPIDY_AUDIO_OUTPUT_REPLAYGAIN:=true}
: ${MOPIDY_SUBIDY_ENABLED:=false}
: ${MOPIDY_SUBIDY_URL:=http://127.0.0.1:8080}
: ${MOPIDY_SUBIDY_USERNAME:=user}
: ${MOPIDY_SUBIDY_PASSWORD:=password}
: ${MOPIDY_BEETS_ENABLED:=false}
: ${MOPIDY_BEETS_HOSTNAME:=127.0.0.1}
: ${MOPIDY_BEETS_PORT:=8337}
: ${MOPIDY_WEBM3U_ENABLED:=false}
: ${MOPIDY_WEBM3U_SEED_M3U:=http://beets:8337/m3u/playlists/index.m3u}
MOPIDY_WEBM3U_NOT_ENABLED="$([ "$MOPIDY_WEBM3U_ENABLED" = true ] && echo false || echo true)"
: ${MOPIDY_M3U_ENABLED:=$MOPIDY_WEBM3U_NOT_ENABLED}

DATA_DIRS='/var/lib/mopidy/autoplay /var/lib/mopidy/local/playlists /var/lib/mopidy/media'
mkdir -p $DATA_DIRS
[ "${MOPIDY_NO_CHMOD:-}" = true ] || chown mopidy:audio $DATA_DIRS
if [ ! -d /var/lib/mopidy/playlists ]; then
	mkdir /var/lib/mopidy/playlists
	cp /etc/mopidy/default-data/playlist.m3u8 /var/lib/mopidy/playlists/
fi

# Generate mopidy config

if [ "${MOPIDY_AUDIO_OUTPUT_PIPE:-}" ]; then
	if [ ! -p "$MOPIDY_AUDIO_OUTPUT_PIPE" ]; then
		echo "Creating PCM audio output pipe at $MOPIDY_AUDIO_OUTPUT_PIPE"
		mkfifo -m 640 "$MOPIDY_AUDIO_OUTPUT_PIPE"
	fi
	MOPIDY_AUDIO_OUTPUT="audioresample ! audioconvert ! audio/x-raw,rate=48000,channels=2,format=S16LE ! filesink location=$MOPIDY_AUDIO_OUTPUT_PIPE"
	if [ "${MOPIDY_AUDIO_OUTPUT_PIPE_GENERATE_SOUND:-true}" = true ]; then
		(
			sleep 9
			sox -V -r 48000 -n -b 16 -c 2 /tmp/start.wav synth 3 sin 0+15000 sin 1000+80000 vol -10db remix 1,2 channels 2 &&
			cat /tmp/start.wav > "$MOPIDY_AUDIO_OUTPUT_PIPE"
		) &
	fi
elif [ "${PULSE_SERVER:-}" ]; then
	MOPIDY_AUDIO_OUTPUT="pulsesink server=$PULSE_SERVER"
else
	echo 'Must specify one env var of MOPIDY_AUDIO_OUTPUT, MOPIDY_AUDIO_OUTPUT_PIPE or PULSE_SERVER but none specified' >&2
	exit 1
fi
if [ "$MOPIDY_AUDIO_OUTPUT_REPLAYGAIN" = true ]; then
	MOPIDY_AUDIO_OUTPUT="rgvolume ! $MOPIDY_AUDIO_OUTPUT"
fi

if [ "$MOPIDY_BEETS_ENABLED" = true ]; then
	BEETS_URL="http://$MOPIDY_BEETS_HOSTNAME:$MOPIDY_BEETS_PORT/"
	if ! wget -qO - "$BEETS_URL" >/dev/null; then
		echo "ERROR: Beets server at $BEETS_URL is not available" >&2
		exit 2
	fi
fi
if [ "$MOPIDY_SUBIDY_ENABLED" = true ]; then
	if ! wget -qO - "$MOPIDY_SUBIDY_URL?u=$MOPIDY_SUBIDY_USERNAME&t=$MOPIDY_SUBIDY_PASSWORD"; then
		echo "ERROR: Subsonic server at $MOPIDY_SUBIDY_URL is not available" >&2
		exit 2
	fi
fi
if [ "$MOPIDY_WEBM3U_ENABLED" = true ]; then
	if ! wget -qO - "$MOPIDY_WEBM3U_SEED_M3U" >/dev/null; then
		echo "ERROR: WebM3U at $MOPIDY_WEBM3U_SEED_M3U is not available" >&2
		exit 2
	fi
fi

if [ "${MOPIDY_YOUTUBE_MUSICAPI_COOKIE:-}" ]; then
	# Write Youtube Music cookie to file
	MOPIDY_YOUTUBE_MUSICAPI_COOKIE_FILE=/tmp/youtube-music-cookie.txt
	echo "$MOPIDY_YOUTUBE_MUSICAPI_COOKIE" > $MOPIDY_YOUTUBE_MUSICAPI_COOKIE_FILE
fi

if [ "${MOPIDY_YOUTUBE_MUSICAPI_AUTH_HEADERS:-}" ]; then
	# Generate ytmusicapi browser.json from authenticated HTTP request's headers
	export MOPIDY_YOUTUBE_MUSICAPI_BROWSER_AUTH_FILE=/tmp/ytmusicapi-browser.json
	echo "Generating $MOPIDY_YOUTUBE_MUSICAPI_BROWSER_AUTH_FILE from MOPIDY_YOUTUBE_MUSICAPI_AUTH_HEADERS"
	python3 /ytmusicapi-login.py
fi

if [ "${MOPIDY_YOUTUBE_MUSICAPI_BROWSER_AUTH:-}" ]; then
	MOPIDY_YOUTUBE_MUSICAPI_BROWSER_AUTH_FILE=/tmp/ytmusicapi-browser.json
	echo "$MOPIDY_YOUTUBE_MUSICAPI_BROWSER_AUTH" > $MOPIDY_YOUTUBE_MUSICAPI_BROWSER_AUTH_FILE
fi

if [ -z ${MOPIDY_MPD_PASSWORD+x} ] || [ "$MOPIDY_MPD_PASSWORD" = generate ]; then
	MOPIDY_MPD_PASSWORD=$(openssl rand -base64 18)
	echo "Generated MPD password: $MOPIDY_MPD_PASSWORD" >&2
fi

cat > /tmp/mopidy.conf <<-EOF
	[http]
	allowed_origins = $MOPIDY_HTTP_ALLOWED_ORIGINS
	[audio]
	output = $MOPIDY_AUDIO_OUTPUT
	[iris]
	snapcast_host = $MOPIDY_IRIS_SNAPCAST_HOST
	snapcast_port = $MOPIDY_IRIS_SNAPCAST_PORT
	[mpd]
	password = $MOPIDY_MPD_PASSWORD
	[youtube]
	enabled = ${MOPIDY_YOUTUBE_ENABLED:-true}
	autoplay_enabled = ${MOPIDY_YOUTUBE_AUTOPLAY_ENABLED:-true}
	strict_autoplay = ${MOPIDY_YOUTUBE_AUTOPLAY_STRICT:-true}
	max_autoplay_length = ${MOPIDY_YOUTUBE_AUTOPLAY_MAX_LENGTH:-600}
	max_degrees_of_separation = ${MOPIDY_YOUTUBE_AUTOPLAY_MAX_DISTANCE:-3}
	api_enabled = ${MOPIDY_YOUTUBE_API_ENABLED:-true}
	youtube_api_key = ${MOPIDY_YOUTUBE_API_KEY:-}
	musicapi_enabled = ${MOPIDY_YOUTUBE_MUSICAPI_ENABLED:-false}
	musicapi_cookiefile = ${MOPIDY_YOUTUBE_MUSICAPI_COOKIE_FILE:-}
	musicapi_browser_authentication_file = ${MOPIDY_YOUTUBE_MUSICAPI_BROWSER_AUTH_FILE:-}
	channel_id = ${MOPIDY_YOUTUBE_MUSICAPI_CHANNEL:-UCYwjcFiUg8PpWM45vpBUc3Q}
	search_results = ${MOPIDY_YOUTUBE_MAX_SEARCH_RESULTS:-15}
	playlist_max_videos = ${MOPIDY_YOUTUBE_MAX_VIDEOS:-20}
	[ytmusic]
	oauth_json = ${MOPIDY_YTMUSIC_OAUTH_JSON:-}
	[soundcloud]
	auth_token = ${MOPIDY_SOUNDCLOUD_AUTH_TOKEN:-}
	explore_songs = ${MOPIDY_SOUNDCLOUD_EXPLORE_SONGS:-25}
	[party]
	votes_to_skip = ${MOPIDY_PARTY_VOTES_TO_SKIP:-3}
	max_tracks = ${MOPIDY_PARTY_MAX_TRACKS:-5}
	[beets]
	enabled = ${MOPIDY_BEETS_ENABLED}
	hostname = ${MOPIDY_BEETS_HOSTNAME}
	port = ${MOPIDY_BEETS_PORT}
	[subidy]
	enabled = ${MOPIDY_SUBIDY_ENABLED}
	url = ${MOPIDY_SUBIDY_URL}
	username = ${MOPIDY_SUBIDY_USERNAME}
	password = ${MOPIDY_SUBIDY_PASSWORD}
	[m3u]
	enabled = ${MOPIDY_M3U_ENABLED}
	[webm3u]
	enabled = ${MOPIDY_WEBM3U_ENABLED}
	seed_m3u = ${MOPIDY_WEBM3U_SEED_M3U}
	uri_scheme = ${MOPIDY_WEBM3U_URI_SCHEME:-m3u}
	[tunein]
	enabled = ${MOPIDY_TUNEIN_ENABLED:-false}
	filter = ${MOPIDY_TUNEIN_FILTER:-}
EOF

MOPIDY_CONF=/etc/mopidy/mopidy.conf:/etc/mopidy/extensions.d:/tmp/mopidy.conf

if [ ! -f /var/lib/mopidy/.local-scanned ]; then
	echo 'Scanning media directory for audio files'
	mopidy --config $MOPIDY_CONF local scan
	touch /var/lib/mopidy/.local-scanned
fi

echo 'Launching Mopidy'
exec mopidy --config $MOPIDY_CONF ${MOPIDY_OPTS:-} "$@"
