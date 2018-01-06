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
# usage: ./deleteFileInPlayList -h
#
# History
# Date            Version        Auteur        Commentaire
# 05/01/2015      1.0            Djhibee        Creation
# 11/09/2016      2.0            Djhibee        More automatismes

# External dependencies:
    source ${BASH_SOURCE%/*}/../SETTINGS
    source ${BASH_SOURCE%/*}/utils.sh

####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################

####### Global variables #######
# Default file to use if no param was given in input
FILE_PLAYLIST_DEFAULT="./toto.m3u"

######## Shell variables ##########
debug_mode=${debug_mode:-0}
#######################
# END OF CONFIGURATION
#######################


#####################################

function usage {
  echo "USAGE: $0 [-h] [-p playlist]

             -p : The playlist containing the files to delete
             -h --help : Display this message
        "
  exit 0
}

function datacheck {
    if [ ! -f "$filePlaylist" ]; then
        echo "$filePlaylist is not a file."
        endProg 2
    fi
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
  filePlaylist="$FILE_PLAYLIST_DEFAULT"
  while getopts "p:h" option
  do
    case $option in
      h)
        usage
        ;;
      p)
        filePlaylist="$OPTARG";
        ;;
      :)
        endProg 1 "Option $OPTARG needs an argument" ;
        ;;
      \?)
        endProg 1 "$OPTARG : invalid option" ;
        ;;
    esac
  done
  log "Processed playlist is: $filePlaylist"
}


##########
#  Main
##########
initialize "$@"

datacheck

# Replace \ by \\
sed 's/\\/\\\\/g' $filePlaylist > "$TMP_DIRECTORY/$filePlaylist.tmp"
tr -d '\r' < "$TMP_DIRECTORY/$filePlaylist.tmp"
#sed -i.bak "s/$(printf '\r')//" "$TMP_DIRECTORY/$filePlaylist.tmp"

echo "... Remove song files from $TMP_DIRECTORY/$filePlaylist.tmp"
while read file; do
  log "File to delete: $file"
	if [ -f "$file" ]; then
        set -x
        rm -f "$file"
        set +x
	else
		echo "$file is not a file!!"
	fi
done < "$TMP_DIRECTORY/$filePlaylist.tmp"

# Clean files
rm -f "$TMP_DIRECTORY/$filePlaylist.tmp"
currentDate="$(date +'%Y%m%d%H%M')"
mv "$filePlaylist" > "$VAR_DIRECTORY/playlists-deleted/$filePlaylist.deleted.$currentDate"

endProg 0
