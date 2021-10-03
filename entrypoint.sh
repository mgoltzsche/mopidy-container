#!/bin/sh

set -eu

: ${MOPIDY_MPD_PASSWORD:=}
: ${MOPIDY_OUTPUT_PIPE}

TMP_MOPIDY_CONF=/tmp/mopidy.conf
echo > $TMP_MOPIDY_CONF

if [ "$MOPIDY_OUTPUT_PIPE" ] && [ ! -p "$MOPIDY_OUTPUT_PIPE" ]; then
	echo "Creating PCM audio output pipe at $MOPIDY_OUTPUT_PIPE"
	mkfifo -m 640 "$MOPIDY_OUTPUT_PIPE"
	cat >> $TMP_MOPIDY_CONF <<-EOF
		[audio]
		output = audioresample ! audioconvert ! audio/x-raw,rate=48000,channels=2,format=S16LE ! filesink location=$MOPIDY_OUTPUT_PIPE
	EOF
fi

cat >> $TMP_MOPIDY_CONF <<-EOF
	[mpd]
	password = $MOPIDY_MPD_PASSWORD
EOF

echo "Launching Mopidy"
exec mopidy --config /etc/mopidy/mopidy.conf:/etc/mopidy/extensions.d:$TMP_MOPIDY_CONF ${MOPIDY_OPTS:-} "$@"
