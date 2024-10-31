# Build gst-plugins-spotify (required by Mopidy-Spotify)
FROM rust:1.82-alpine3.20 AS gst-plugins-spotify
RUN apk add --update --no-cache git musl-dev pkgconf glib-dev glib-static gstreamer-dev
#ARG GST_PLUGINS_RS_VERSION=0.12.11
ARG GST_PLUGINS_RS_VERSION=spotify-access-token-logging
# Currently a gst-plugins-rs fork is required for token-based access.
# See https://github.com/mopidy/mopidy-spotify/tree/v5.0.0a3?tab=readme-ov-file#dependencies
RUN git clone -c 'advice.detachedHead=false' --depth=1 --branch=$GST_PLUGINS_RS_VERSION https://gitlab.freedesktop.org/kingosticks/gst-plugins-rs.git
WORKDIR /gst-plugins-rs
ENV RUSTFLAGS='-C target-feature=-crt-static'
RUN cargo build --package gst-plugin-spotify --release


# Build final mopidy container
FROM python:3.12-alpine3.20
RUN set -eux; \
	BUILD_DEPS='python3-dev gcc musl-dev cairo-dev gobject-introspection-dev'; \
	apk add --update --no-cache $BUILD_DEPS py3-pip py3-gst cairo gobject-introspection gst-plugins-good gst-plugins-bad sox openssl ca-certificates git bash jq; \
	python3 -m pip install --break-system-packages \
		Mopidy==3.4.2 \
		PyGObject==3.46.0 \
		Mopidy-Iris==3.69.3 \
		Mopidy-Autoplay==0.2.3 \
		Mopidy-MPD==3.3.0 \
		Mopidy-Local==3.2.1 \
		Mopidy-SoundCloud==3.0.2 \
		Mopidy-Podcast==3.0.1 \
		Mopidy-SomaFM==2.0.2 \
		Mopidy-TuneIn==1.1.0 \
		Mopidy-Party==1.2.1 \
		Mopidy-AlarmClock==0.1.9 \
		Mopidy-WebM3U==0.1.3 \
		Mopidy-Spotify==5.0.0a3 \
		ytmusicapi==1.3.2 \
		yt-dlp==2024.10.22; \
	apk del --purge $BUILD_DEPS

# Mopidy-Youtube==3.7
ARG MOPIDY_YOUTUBE_VERSION=f14535e6aeec19d5a581aebe4b8143211b462cc4 # 3.7 + ytmusicapi auth patch
RUN python3 -m pip install git+https://github.com/natumbri/mopidy-youtube.git@$MOPIDY_YOUTUBE_VERSION

# yt-dlp==2023.11.16 + patches
#ARG YTDLP_VERSION=bc4ab17b38f01000d99c5c2bedec89721fee65ec
#RUN python3 -m pip install git+https://github.com/yt-dlp/yt-dlp@$YTDLP_VERSION

# Install Mopidy-YTMusic from fork that supports newer pytube version.
# Unfortunately, that did not help.
# See https://github.com/OzymandiasTheGreat/mopidy-ytmusic/issues/41
#ARG MOPIDY_YTMUSIC_VERSION=c60055bc4cbc35534ef4c141fc883928bf5ca280 # 0.3.8 + pytube patch
#RUN python3 -m pip install git+https://github.com/mgoltzsche/mopidy-ytmusic.git@$MOPIDY_YTMUSIC_VERSION

# Mopidy-Beets==4.0.1 + none-album patch
ARG MOPIDY_BEETS_VERSION=7fbdf56c6b6b8318974e4add6446e15654df4bea
RUN python3 -m pip install git+https://github.com/mopidy/mopidy-beets@$MOPIDY_BEETS_VERSION

# Mopidy-Subidy==1.0.0 + coverart support
ARG MOPIDY_SUBIDY_VERSION=fa3b21216d1a3b937e926d289f8f18f8277b6cc7
RUN python3 -m pip install git+https://github.com/mgoltzsche/mopidy-subidy@$MOPIDY_SUBIDY_VERSION

COPY --from=gst-plugins-spotify /gst-plugins-rs/target/release/libgstspotify.so /usr/lib/gstreamer-1.0/

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
