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
# usage: bash ./synoindexNewImports -h
# Si pas de timetamp fourni, on prend la date courante


# External dependencies:
    source ${BASH_SOURCE%/*}/../SETTINGS
    source ${BASH_SOURCE%/*}/utils.sh


####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################

####### Global variables #######

######## Shell variables ##########
debug_mode=${debug_mode:-0}
#######################
# END OF CONFIGURATION
#######################


TIME_STAMP_DEFAULT="$(date +'%Y%m%d%H%M')"

function usage {
  echo "USAGE: $0 [-h] [-t timestamp]

             -t : The timestamp from where indexing new imports, with timestamp format=%Y%m%d%H%M (e.g 201609120540)
             -h --help : Display this message
        "
  exit 0
}

# Set shell attributes and initialize output files
function initialize {
  if [[ $1 =~ ^--help ]]; then
    usage
  fi
  echo "$0 script started..."
  if [ "$debug_mode" -eq 1 ]; then
    echo "debug mode is ON"
  else
    echo "debug mode is OFF"
  fi
  timestamp="$TIME_STAMP_DEFAULT"
  while getopts "t:h" option
  do
    case $option in
      h)
        usage
        ;;
      t)
        timestamp="$OPTARG";
        ;;
      :)
        endProg 1 "Option $OPTARG needs an argument" ;
        ;;
      \?)
        endProg 1 "$OPTARG : invalid option" ;
        ;;
    esac
  done
}

##########
#  Main
##########
initialize "$@"

echo "... Starting $IMPORT_FEEDS_DIRECTORY processing..."
# filter only .m3u file from given IMPORT_FEEDS_DIRECTORY
ls -1  $IMPORT_FEEDS_DIRECTORY |  grep .m3u$ > "$TMP_DIRECTORY/playlists.tmp"

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
done < "$TMP_DIRECTORY/playlists.tmp"

# Clean files
if [ "$debug_mode" -lt 1 ]; then
  rm -f "$TMP_DIRECTORY/playlists.tmp"
fi
