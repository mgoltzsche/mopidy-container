FROM alpine:3.17
RUN apk add --update --no-cache python3-dev py3-pip py3-gst gst-plugins-good gst-plugins-bad sox openssl ca-certificates git
RUN python3 -m pip install \
	Mopidy==3.4.2 \
	Mopidy-Iris==3.69.2 \
	Mopidy-Autoplay==0.2.3 \
	Mopidy-MPD==3.3.0 \
	Mopidy-Local==3.2.1 \
	yt-dlp==2023.11.16 \
	ytmusicapi==1.3.2 \
	Mopidy-SoundCloud==3.0.2 \
	Mopidy-Podcast==3.0.1 \
	Mopidy-SomaFM==2.0.2 \
	Mopidy-TuneIn==1.1.0 \
	Mopidy-Party==1.2.1 \
	Mopidy-AlarmClock==0.1.9

# Mopidy-Youtube==3.7
ARG MOPIDY_YOUTUBE_VERSION=c76815ffedb9f119d1d9129645efc85865f5b4b7 # 3.7 + ytmusicapi auth patch
RUN python3 -m pip install git+https://github.com/natumbri/mopidy-youtube.git@$MOPIDY_YOUTUBE_VERSION

ARG YTDLP_VERSION=c1d71d0d9f41db5e4306c86af232f5f6220a130b
RUN python3 -m pip install git+https://github.com/yt-dlp/yt-dlp@$YTDLP_VERSION

# Install Mopidy-YTMusic from fork that supports newer pytube version.
# Unfortunately, that did not help.
# See https://github.com/OzymandiasTheGreat/mopidy-ytmusic/issues/41
#ARG MOPIDY_YTMUSIC_VERSION=c60055bc4cbc35534ef4c141fc883928bf5ca280 # 0.3.8 + pytube patch
#RUN python3 -m pip install git+https://github.com/mgoltzsche/mopidy-ytmusic.git@$MOPIDY_YTMUSIC_VERSION

# Mopidy-Beets==4.0.1 fork
ARG MOPIDY_BEETS_VERSION=f4a078e9718ffd5c7ae2f8eedb0206921a3e1a50
RUN python3 -m pip install git+https://github.com/mgoltzsche/mopidy-beets@$MOPIDY_BEETS_VERSION

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
HEALTHCHECK --interval=5s --timeout=3s CMD wget -O - http://127.0.0.1:6680/mopidy/
