FROM python:3-alpine3.19
RUN set -eux; \
	BUILD_DEPS='python3-dev gcc musl-dev cairo-dev gobject-introspection-dev'; \
	apk add --update --no-cache $BUILD_DEPS py3-pip py3-gst cairo gobject-introspection gst-plugins-good gst-plugins-bad sox openssl ca-certificates git bash jq; \
	python3 -m pip install \
		Mopidy==3.4.2 \
		PyGObject==3.46.0 \
		Mopidy-Iris==3.69.2 \
		Mopidy-Autoplay==0.2.3 \
		Mopidy-MPD==3.3.0 \
		Mopidy-Local==3.2.1 \
		Mopidy-SoundCloud==3.0.2 \
		Mopidy-Podcast==3.0.1 \
		Mopidy-SomaFM==2.0.2 \
		Mopidy-TuneIn==1.1.0 \
		Mopidy-Party==1.2.1 \
		Mopidy-AlarmClock==0.1.9 \
		ytmusicapi==1.3.2; \
	apk del $BUILD_DEPS

# Mopidy-Youtube==3.7
ARG MOPIDY_YOUTUBE_VERSION=f14535e6aeec19d5a581aebe4b8143211b462cc4 # 3.7 + ytmusicapi auth patch
RUN python3 -m pip install git+https://github.com/natumbri/mopidy-youtube.git@$MOPIDY_YOUTUBE_VERSION

# yt-dlp==2023.11.16 + patches
ARG YTDLP_VERSION=bc4ab17b38f01000d99c5c2bedec89721fee65ec
RUN python3 -m pip install git+https://github.com/yt-dlp/yt-dlp@$YTDLP_VERSION

# Install Mopidy-YTMusic from fork that supports newer pytube version.
# Unfortunately, that did not help.
# See https://github.com/OzymandiasTheGreat/mopidy-ytmusic/issues/41
#ARG MOPIDY_YTMUSIC_VERSION=c60055bc4cbc35534ef4c141fc883928bf5ca280 # 0.3.8 + pytube patch
#RUN python3 -m pip install git+https://github.com/mgoltzsche/mopidy-ytmusic.git@$MOPIDY_YTMUSIC_VERSION

# Mopidy-Beets==4.0.1 + none-album patch
ARG MOPIDY_BEETS_VERSION=dfb11601f4cb617281707486d886f01952e90ebb
RUN python3 -m pip install git+https://github.com/mopidy/mopidy-beets@$MOPIDY_BEETS_VERSION

COPY conf /etc/mopidy/extensions.d
RUN set -ex; \
	mkdir -p /etc/mopidy/podcast /config; \
	adduser -Su 100 -G audio -h /var/lib/mopidy mopidy mopidy; \
	addgroup -g 4242 snapserver; \
	addgroup mopidy snapserver; \
	mkdir -m2755 /snapserver; \
	chown mopidy:snapserver /snapserver; \
	touch /IS_CONTAINER; \
	ln -s /etc/mopidy/mopidy.conf /config/mopidy.conf
COPY mopidy.conf /etc/mopidy/mopidy.conf
COPY default-data/Podcasts.opml /etc/mopidy/podcast/Podcasts.opml
COPY default-data /etc/mopidy/default-data
USER mopidy:audio
ENV MOPIDY_MPD_PASSWORD=generate \
	MOPIDY_IRIS_SNAPCAST_PORT=443
COPY entrypoint.sh ytmusicapi-login.py /
ENTRYPOINT [ "/entrypoint.sh" ]
HEALTHCHECK --interval=10s --timeout=3s CMD wget -O - http://127.0.0.1:6680/mopidy/
