#!/bin/bash
# Parse IMPORT_FEEDS_DIRECTORY to index recently imported albums with synoindex
#
# Useful commands:
# find $IMPORT_FEEDS_DIRECTORY -print0 | xargs -0  cat | cut -f1,2,3,4,5 -d'/' >
# awk '$0 ~ /\/.*\/.*\/.*\/.*\.mp3/ {print $0}' < ./toot/text.txt
# awk -F - '{print $1 (NF>1? FS $2 : "")}' <<<'After-u-math-how-however'
# xargs -0  < <(cut -f1,2,3,4 -d'/' < ./toot/text.txt)
#ls -d -1 /Users/jchapeland/toot/* | xargs -n 1 cat  | cut -f1,2,3,4,5 -d'/' | xargs  -n 1
#find ./toot -print0 | xargs -0 -n 1 -x cat | cut -f1,2,3,4,5 -d'/' | xargs  -n 1
#cat "playlists.tmp"
# awk -F - '{print $1 (NF>1? FS $2 : "")}' <<<'After-u-math-how-however'
#while read album; do echo The album to index is "$album"; done < <(find ./toot/*.* -print0 | xargs -0  cat | cut -f1,2,3,4,5 -d'/')
# creationDate=`stat -t "%Y%m%d%H%M" -f "%Sm " "$IMPORT_FEEDS_DIRECTORY"/$playlist``
# creationDate=`echo $playlist|awk -F _ '{print $1$2}'|sed 's/h//g'`
# tr -d '\r' < $filePlaylist.tmp
# double slash means global substitution to replace all occurences
#     newComments="${newComments//,[4321]-stars/}"
# if echo $oldComments | grep -i "$playlistRatingName"; then
# sed 's/\\/\\\\/g' $filePlaylist > $filePlaylist.tmp
#
# to debug by displaying commands, use set -x before and set +x after
#
# Algo:
# Get all playlists in IMPORT_FEEDS_DIRECTORY
# For each playlist
#   -> if $timestamp is inferior
#       -> extract album_Path from first mp3
#       -> synoindex -A $album_path
#
# usage: bash ./01_synoindexNewImports timestamp avec timestamp format=%Y%m%d%H%M (e.g 201609120540)
# Si pas de timetamp fourni, on prend la date courante
# History
# Date            Version        Auteur        Commentaire
# 07//09/2016      1.0            JB Chapeland        Creation
# 11//09/2016      2.0            JB Chapeland        Cleaned

IMPORT_FEEDS_DIRECTORY="/volume1/music/playlists/imports"
TIME_STAMP_DEFAULT="$(date +'%Y%m%d%H%M')"

debug_mode=0

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
	timestamp=$1
else
  timestamp=$TIME_STAMP_DEFAULT
fi

echo "... Starting $IMPORT_FEEDS_DIRECTORY processing..."
# filter only .m3u file from given IMPORT_FEEDS_DIRECTORY
ls -1  $IMPORT_FEEDS_DIRECTORY |  grep .m3u$ > playlists.tmp

while read playlist; do
	log "Playlist is $playlist"
	# use on macos:
  #creationDate=`stat -t "%Y%m%d%H%M" -f "%Sm " "$IMPORT_FEEDS_DIRECTORY"/$playlist``
	# format of playlist should be 20160910_18h21_Get_a_Grip.m3u
	creationDate=`echo $playlist|awk -F _ '{print $1$2}'|sed 's/h//g'`
	# => 201609101821
  log "Creationdate is $creationDate"
  if [ $creationDate -gt $timestamp ]; then
		# cut after the fifth slash and and take the first line of file
		# ATTENTION!!! DEPend de la valeur de $directory dans le config.yaml (/volume1/music/)
		# /volume1/music/Aerosmith (US)/[1993] Get a Grip
    album="`cat "$IMPORT_FEEDS_DIRECTORY"/$playlist | cut -f1,2,3,4,5 -d'/' | head -1 `"
    synoindex -A "$album"
    log "$album"
  fi
done < "playlists.tmp"

# Clean files
if [ "$debug_mode" = 0 ]; then
  rm -f "playlists.tmp"
fi
