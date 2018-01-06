#!/bin/sh

# Synopsis :
#           Correct the country of artists from a directory list.
#
# Usage:   ./cleanArtistCountry artistDirectoriesToTreat.txt
#
# Prerequisites:
#               1. directories are named with the convention: ~/artistname (artistcountry)
#               2. artistDirectoriesToTreat.txt must contain one artist per line
#               3. On one line,first directory is the one with the good country, others are the ones to correct
#               4. Directories must be separated by a '?' char (used because should not be present in artists'names)
#       e.g: /Users/superToto/Music/music-lossless/Nancy Sinatra (US)?/Users/superToto/Music/music-lossless/Nancy Sinatra (GB)
#
# External dependencies:
#                       - NEEDS AWK LIBRARY!!!!!
#
# Useful commands:
#     Use this to create  dirs:
#       ls -d -1 $PWD/**
#     this for files:
#       ls -d -1 $PWD/*.*
#     this for everything:
#       ls -d -1 $PWD/**/*

####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################
# Beets' config for library to clean
CONFIG_MP3="/Users/superToto/.config/beets/config.yaml"
# Default file to use if no param was given in input
FILE_PLAYLIST_DEFAULT="./toto.m3u"

####################################

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

# datacheck
function datacheck {

    if [ ! -f $filePlaylist ]; then
        echo "$filePlaylist is not a file."
        endProg 2
    fi
}

echo "... Get parameters"

if [ $# -gt 0 ]; then
	filePlaylist=$1
else
    filePlaylist=$FILE_PLAYLIST_DEFAULT
fi
prog=$0
repAnalyse=`dirname $prog`

echo "Processed playlist is: $filePlaylist"

datacheck

# Replace \ by \\
sed 's/\\/\\\\/g' $filePlaylist > $filePlaylist.tmp
sed -i.bak "s/$(printf '\r')//" $filePlaylist.tmp

echo "... Starting $filePlaylist.tmp processing"
countFoundFromPlaylist=0

while read file; do
      numberOfWrongArtists=$((`echo "$file" | awk -F? '{print NF}'`-1))
      trueArtistPath="`echo "$file" | awk -F? '{print $1}'`"
      #echo "Nombre de mauvais artists $numberOfWrongArtists"
      myalbumartist="`beet -c $CONFIG_MP3 list path:"$trueArtistPath" -f '$mb_albumartistid' | awk 'NR == 1 {print $0}'`"
      echo "vrai artist: $myalbumartist"

      for ((i=2;i<=numberOfWrongArtists+1;i++));do
        otherArtistPath="`echo "$file" | awk -v i=$i -F? '{print $i}'`"
        myfalsealbumartist="`beet -c $CONFIG_MP3 list path:"$otherArtistPath" -f '$mb_albumartistid' | awk 'NR == 1 {print $0}'`"
        echo "false artist: $myfalsealbumartist"
        echo "Current fake artist path: $otherArtistPath"
        #beet -c $CONFIG_MP3 modify -y path:"$otherArtistPath" mb_albumartistid=""
        beet -c $CONFIG_MP3 modify -y path:"$otherArtistPath" mb_albumartistid="$myalbumartist" mb_artistid="$myalbumartist"
        #beet -c $CONFIG_MP3 move path:"$otherArtistPath"
      done
      echo "end processing $trueArtistPath"

done < "$filePlaylist.tmp"

#beet -c $CONFIG_MP3 list -p comments="2-stars" > "$filePlaylist".new.txt

endProg 0
