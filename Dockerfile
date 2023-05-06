FROM alpine:3.17
RUN apk add --update --no-cache mopidy py3-pip python3-dev sox openssl ca-certificates gst-plugins-bad
RUN python3 -m pip install Mopidy-Iris Mopidy-Autoplay Mopidy-MPD \
	Mopidy-Local Mopidy-YouTube ytmusicapi Mopidy-YTMusic Mopidy-SoundCloud Mopidy-Podcast \
	Mopidy-SomaFM Mopidy-TuneIn
#RUN set -ex; \
#	wget -O /tmp/ffmpeg.tar.xz https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz
#	tar -xzf /tmp/ffmpeg.tar.xz -C /tmp/ffmpeg

ARG YTDLP_VERSION=2023.03.04
RUN python3 -m pip install https://github.com/yt-dlp/yt-dlp/archive/${YTDLP_VERSION}.tar.gz
#ARG YTDLP_VERSION=b423b6a48e0b19260bc95ab7d72d2138d7f124dc
#RUN apk add --update --no-cache git
#RUN python3 -m pip install git+https://github.com/yt-dlp/yt-dlp@${YTDLP_VERSION}
#RUN yt-dlp --version && false
#RUN apk add --update --no-cache gstreamer gstreamer-lang gstreamer-vaapi gst-plugins-bad-dev gst-plugins-base-dev

COPY conf /etc/mopidy/extensions.d
RUN set -ex; \
	mkdir -p /etc/mopidy/podcast /config; \
	addgroup -g 4242 snapserver; \
	addgroup mopidy snapserver; \
	mkdir -m2755 /snapserver; \
	chown mopidy:snapserver /snapserver; \
	rm /etc/mopidy/mopidy.conf; \
	touch /IS_CONTAINER; \
	ln -s /etc/mopidy/mopidy.conf /config/mopidy.conf
COPY mopidy.conf /etc/mopidy/mopidy.conf
COPY default-data/Podcasts.opml /etc/mopidy/podcast/Podcasts.opml
COPY default-data /etc/mopidy/default-data
USER mopidy:audio
ENV MOPIDY_MPD_PASSWORD=generate \
	MOPIDY_IRIS_SNAPCAST_PORT=443
COPY entrypoint.sh /
ENTRYPOINT [ "/entrypoint.sh" ]
HEALTHCHECK --interval=5s --timeout=3s CMD wget -O - http://127.0.0.1:6680/mopidy/
