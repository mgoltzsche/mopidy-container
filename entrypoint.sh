#!/bin/sh

set -eu

: ${MOPIDY_HTTP_ALLOWED_ORIGINS:=https://${HOSTNAME},https://${HOSTNAME}:8443,https://localhost:8443,https://localhost}
: ${MOPIDY_SNAPCAST_PORT:=1780}

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

TMP_MOPIDY_CONF=/tmp/mopidy.conf

cat > $TMP_MOPIDY_CONF <<-EOF
	[http]
	allowed_origins = $MOPIDY_HTTP_ALLOWED_ORIGINS
	[audio]
	output = $MOPIDY_AUDIO_OUTPUT
	[iris]
	data_dir = /var/lib/mopidy/iris
	snapcast_host = $HOSTNAME
	snapcast_port = ${MOPIDY_SNAPCAST_PORT:=1780}
	[mpd]
	password = $MOPIDY_MPD_PASSWORD
EOF

echo "Launching Mopidy"
exec mopidy --config /etc/mopidy/mopidy.conf:/etc/mopidy/extensions.d:$TMP_MOPIDY_CONF ${MOPIDY_OPTS:-} "$@"
