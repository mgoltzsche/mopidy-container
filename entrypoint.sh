#!/bin/sh

set -eu

: ${MOPIDY_HTTP_ALLOWED_ORIGINS:=https://${HOSTNAME},https://${HOSTNAME}:8443}
: ${MOPIDY_IRIS_SNAPCAST_HOST:=$HOSTNAME}

DATA_DIRS='/var/lib/mopidy/autoplay /var/lib/mopidy/local/playlists /var/lib/mopidy/media'
mkdir -p $DATA_DIRS
chown mopidy:audio $DATA_DIRS
if [ ! -d /var/lib/mopidy/playlists ]; then
	mkdir /var/lib/mopidy/playlists
	cp /etc/mopidy/default-data/playlist.m3u8 /var/lib/mopidy/playlists/
fi

# Generate mopidy config

if [ -z ${MOPIDY_MPD_PASSWORD+x} ] || [ "$MOPIDY_MPD_PASSWORD" = generate ]; then
	MOPIDY_MPD_PASSWORD=$(openssl rand -base64 18)
	echo "Generated MPD password: $MOPIDY_MPD_PASSWORD" >&2
fi

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
fi

if [ "${MOPIDY_YOUTUBE_MUSICAPI_COOKIE:-}" ]; then
	# Write Youtube Music cookie to file
	MOPIDY_YOUTUBE_MUSICAPI_COOKIE_FILE=/tmp/youtube-music-cookie.txt
	echo "$MOPIDY_YOUTUBE_MUSICAPI_COOKIE" > $MOPIDY_YOUTUBE_MUSICAPI_COOKIE_FILE
fi

cat > /tmp/mopidy.conf <<-EOF
	[http]
	port = ${MOPIDY_HTTP_PORT:-6680}
	allowed_origins = $MOPIDY_HTTP_ALLOWED_ORIGINS
	[audio]
	output = $MOPIDY_AUDIO_OUTPUT
	[iris]
	snapcast_host = $MOPIDY_IRIS_SNAPCAST_HOST
	snapcast_port = $MOPIDY_IRIS_SNAPCAST_PORT
	[mpd]
	port = ${MOPIDY_MPD_PORT:-6600}
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
	channel_id = ${MOPIDY_YOUTUBE_MUSICAPI_CHANNEL:-UCYwjcFiUg8PpWM45vpBUc3Q}
	musicapi_cookiefile = ${MOPIDY_YOUTUBE_MUSICAPI_COOKIE_FILE:-}
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
EOF

MOPIDY_CONF=/etc/mopidy/mopidy.conf:/etc/mopidy/extensions.d:/tmp/mopidy.conf

if [ ! -f /var/lib/mopidy/.local-scanned ]; then
	echo 'Scanning media directory for audio files'
	mopidy --config $MOPIDY_CONF local scan
	touch /var/lib/mopidy/.local-scanned
fi

echo 'Launching Mopidy'
mopidy --config $MOPIDY_CONF ${MOPIDY_OPTS:-} "$@" || (sleep 1; false)
