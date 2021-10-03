FROM alpine:3.14
RUN apk add --update --no-cache mopidy py3-pip python3-dev py3-mopidy-youtube
RUN python3 -m pip install Mopidy-Iris Mopidy-Autoplay Mopidy-MPD \
	Mopidy-Local Mopidy-YouTube Mopidy-SoundCloud Mopidy-Podcast \
	Mopidy-SomaFM Mopidy-TuneIn
COPY conf /etc/mopidy/extensions.d
RUN set -ex; \
	mkdir /etc/mopidy/podcast; \
	addgroup -g 4242 snapserver; \
	addgroup mopidy snapserver; \
	mkdir -m2755 /snapserver; \
	chown mopidy:snapserver /snapserver
USER mopidy:audio
ENV MOPIDY_OUTPUT_PIPE=
COPY entrypoint.sh /
ENTRYPOINT [ "/entrypoint.sh" ]
