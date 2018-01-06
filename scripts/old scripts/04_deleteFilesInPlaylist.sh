#!/bin/sh

# Synopsis :
#       Delete all files from a playlist (physical files will be deleted, not only removed from playlist..)
#       For example, use this in order to erase  1-stars ranked songs.
# Algo :
# For each file in the playlist
# 	-> erase the file if it exists
# Move playlist to $filePlaylist.deleted.$currentDate"

# Prerequisites:
#         1. Have a list of files to delete.
#         beet -v -c ~/.config/beets/config-mp3-toProcess.yaml list comments::”1-stars” > toRemove.txt
#
# usage: ./deleteFileInPlayList playlist-name
#
# History
# Date            Version        Auteur        Commentaire
# 05/01/2015      1.0            Djhibee        Creation
# 11/09/2016      2.0            Djhibee        More automatismes

####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################
# Default file to use if no param was given in input
FILE_PLAYLIST_DEFAULT="./toto.m3u"
debug_mode=1

#####################################

function endProg {
    end=$1
    args=$*
    if [ $end -gt 0 ]; then
        echo "End of script with error"
        if [ $# -gt 1 ]; then
            echo "$args"
        fi
        exit $end
    else
        echo "Script ended normally"
        exit 0
    fi
}

function datacheck {
    if [ ! -f "$filePlaylist" ]; then
        echo "$filePlaylist is not a file."
        endProg 2
    fi
}

# Print debug logs if debug_mode==true
function log {
  if [ "$debug_mode" = 1 ]; then
    echo "$1"
    printf "\r"
  fi
}

if [ "$debug_mode" = 1 ]; then
  echo "debug mode is ON"
else
  echo "debug mode is OFF"
fi

echo "... Get parameters"
if [ $# -gt 0 ]; then
	filePlaylist=$1
else
    filePlaylist=$FILE_PLAYLIST_DEFAULT
fi

echo "Default playlist is: $FILE_PLAYLIST_DEFAULT"
echo "Processed playlist is: $filePlaylist"

datacheck

# Replace \ by \\
sed 's/\\/\\\\/g' $filePlaylist > $filePlaylist.tmp
tr -d '\r' < $filePlaylist.tmp
#sed -i.bak "s/$(printf '\r')//" $filePlaylist.tmp

echo "... Remove song files from $filePlaylist.tmp"
while read file; do
  log "File to delete: $file"
	if [ -f "$file" ]; then
        set -x
        rm -f "$file"
        set +x
	else
		echo "$file is not a file!!"
	fi
done < $filePlaylist.tmp

# Clean files
rm -f "$filePlaylist.tmp"
currentDate="$(date +'%Y%m%d%H%M')"
mv "$filePlaylist" > "$filePlaylist.deleted.$currentDate"

endProg 0
