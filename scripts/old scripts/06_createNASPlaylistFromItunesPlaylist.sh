#!/bin/bash

# Synopsis :
#           Get all files from a local itunes playlist and create the same playlist using files from NAS.
#           Song order is conserved.
#
# Usage:
#           ./createNASPlaylistFromItunesPlaylist itunePlaylist
# Output:
#            a file called itunePlaylist-NAS
# Algo:
# For each file in the playlist
#   -> fetch  beets attributes from EXTINF part
#   -> get corresponding NAS file
#      beet  -c $CONFIG_MUSIC list -p title:"$title" artist:"$artist"
#   -> update new playlist
#       echo >> playlist-NAS
#
# WARNING: No space allowed in playlists! => because if [ ! -f $filePlaylist ]; failed otherwise
#
# External dependencies:
#                       - NEEDS AWK LIBRARY!!!!!
#
# History
# Date            Version        Auteur        Commentaire
# 06/11/2016      1.0            Djhibee        Creation

####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################
# Beets' config for library
CONFIG_MUSIC="/var/services/homes/djhibee/.config/beets/config.yaml"
# Default file to use in case no param was given in input
FILE_PLAYLIST_DEFAULT="./toto.m3u"
debug_mode=1
RED_COLOR=${RED_COLOR:-'\033[0;31m'}
NO_COLOR=${NO_COLOR:-'\033[0m'}
LOG_COLOR_DEFAULT=${LOG_COLOR_DEFAULT:-$NO_COLOR}
#######################
# END OF CONFIGURATION
#######################
#####################
## Global variables
#####################
# Stats to display after process
countNotFoundFromPlaylist=0
# Stores all songs from the itunes playlist for whose no corresponding file was found on NAS
FILE_NOT_FOUND_ON_NAS=""


function log {
  typeset logcolor
  if [ $# -gt 1 ]; then
  	logColor="$2"
  else
    logColor="$LOG_COLOR_DEFAULT"
  fi
  if [ "$debug_mode" -eq 1 ]; then
    echoInColor "$1" "$logColor"
  fi
}

function echoInColor {
  typeset echoColor
  if [ $# -gt 1 ]; then
    echoColor="$2"
  else
    echoColor="$LOG_COLOR_DEFAULT"
  fi
  echo -e "$echoColor $1"
  printf "${LOG_COLOR_DEFAULT}\r"
}

function endProg {
    end=$1
    args=$*
    if [ $end -gt 0 ]; then
        echoInColor "End of script with error:" "$RED_COLOR"
        if [ $# -gt 1 ]; then
            echoInColor "$args" "$RED_COLOR"
        fi
        exit $end
    else
        echoInColor "Script ended normally" "$LOG_COLOR_DEFAULT"
        exit 0
    fi
}

function datacheck {
    if [ ! -f "$filePlaylist" ]; then
        endProg 2 "$filePlaylist is not a file."
    fi
}


function printNotFoundFile {
  NASFileNotFound="$1"
  log "NOT FOUND NAS file for: $NASFileNotFound"
  echo "$NASFileNotFound" >> "$FILE_NOT_FOUND_ON_NAS"
  countNotFoundFromPlaylist=$((countNotFoundFromPlaylist + 1))
}

echo "createNASPlaylistFromItunesPlaylist started..."

if [ "$debug_mode" = 1 ]; then
  echo "debug mode is ON"
else
  echo "debug mode is OFF"
fi

echo "... Get parameters"

if [ $# -gt 0 ]; then
	filePlaylist="$1"
else
    filePlaylist=$FILE_PLAYLIST_DEFAULT
fi

FILE_NOT_FOUND_ON_NAS="$filePlaylist.notFoundOnNas.txt"

echo "Processed playlist is: $filePlaylist"
echo "Fichiers non trouves dumpes dans  $FILE_NOT_FOUND_ON_NAS"

datacheck

echo "... Starting $filePlaylist processing"
# Replace \ by \\ and create a copy of the playlist to work on it
sed 's/\r/\r\n/g' $filePlaylist > $filePlaylist.tmp

while read file; do
  fileProper="$file"
  # uncomment when running on Macosx
  #fileProper="`iconv -f utf-8 -t utf-8-mac <<< "$file"`"
  log "Processing $fileProper"
  # Parse only extinf lines that contain artist and title of songs
  # example #EXTINF:261,Blame It (Original mix) - Jamiee Foxx feat. T-Pain
  if echo $fileProper | grep -i "EXTINF"; then
    # the following handles the case where , or - appears several times in artist or title
    tmp=`echo "$fileProper" | awk 'BEGIN { FS = "," ; ORS = "" ; } ; { for (i=2; i<NF; i++) print $i FS} ; { print $NF "\r\n"}'`
    #tmp=Blame It (Original mix) - Jamiee Foxx feat. T-Pain
    #artist=`./getArtistName.awk <<< "$tmp"`
    #title=`./getSongTitle.awk <<< "$tmp"`
    artist=`echo $tmp| awk 'BEGIN { FS = " - " } ; { print $2 }'`
    title=`echo $tmp| awk 'BEGIN { FS = " - " } ; { print $1 }'`
    log "artist:$artist"
    log "title:$title"
    # get path on NAS from beet mp3 library
    # } must be escaped with $ (see beet doc)
    # We put it in a file because the result could return several paths
    beet  -c $CONFIG_MUSIC list -p albumartist:"$artist" "title:$title" > file_Path_OnNas.tmp
    filefound=false
    while read pathOnNas; do
        if [[ ! -z "$pathOnNas" ]]
        then
          # song was found we take the first one returned
          echo "$pathOnNas" >> $filePlaylist-NAS
          echo "$pathOnNas"
          filefound=true
          break
        fi
    done < file_Path_OnNas.tmp

    if $filefound ; then
        log "the file was found we continue the loop to the next song"
        continue
    else
      # la chanson n a pas ete trouvee du tout
      printNotFoundFile "$fileProper"
    fi
  fi
done < "$filePlaylist.tmp"

echo "number of files not found from playlist: $countNotFoundFromPlaylist"

# Clean files
if [ "$debug_mode" = 0 ]; then
  rm -f "$file_Path_OnNas.tmp"
  #rm -f "$filePlaylist.tmp"
fi

endProg 0
