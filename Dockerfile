FROM alpine:3.17
RUN apk add --update --no-cache mopidy py3-pip python3-dev sox openssl ca-certificates gst-plugins-bad git
RUN python3 -m pip install \
	Mopidy-Iris==3.68.0 \
	Mopidy-Autoplay==0.2.3 \
	Mopidy-MPD==3.3.0 \
	Mopidy-Local==3.2.1 \
	Mopidy-Youtube==3.7 \
	yt-dlp==2023.7.6 \
	ytmusicapi==1.2.1 \
	Mopidy-SoundCloud==3.0.2 \
	Mopidy-Podcast==3.0.1 \
	Mopidy-SomaFM==2.0.2 \
	Mopidy-TuneIn==1.1.0 \
	Mopidy-Party==1.2.1 \
	Mopidy-AlarmClock==0.1.9

# Install Mopidy-YTMusic from fork that supports newer ytmusicapi version than 0.23.0 - doesn't work anyway, unfortunately
# See https://github.com/OzymandiasTheGreat/mopidy-ytmusic/issues/41
#ARG MOPIDY_YTMUSIC_VERSION=c60055bc4cbc35534ef4c141fc883928bf5ca280 # 0.3.8 + pytube patch
#RUN python3 -m pip install git+https://github.com/mgoltzsche/mopidy-ytmusic.git@$MOPIDY_YTMUSIC_VERSION

#ARG YTDLP_VERSION=2023.07.06
#RUN python3 -m pip install https://github.com/yt-dlp/yt-dlp/archive/${YTDLP_VERSION}.tar.gz

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
