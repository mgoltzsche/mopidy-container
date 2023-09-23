import os
import ytmusicapi

path=os.environ['MOPIDY_YOUTUBE_MUSICAPI_BROWSER_AUTH_FILE']
headers=os.environ['MOPIDY_YOUTUBE_MUSICAPI_AUTH_HEADERS']

ytmusicapi.setup(filepath=path, headers_raw=headers)
