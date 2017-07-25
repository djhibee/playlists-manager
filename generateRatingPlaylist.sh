#!/bin/bash
#
# Synopsis :
#           Medium level script.
#           Use Synology's Audio station API to generate ratings playlists.
#
# Usage:    Run generateRatingPlaylist.sh --help
#
# Output: Rating playlists created in playlistDestinationDirectory named with convention ratingNumber-stars.m3u, i.e 5-stars.m3u
#
# Prerequisites:
#               1. change User, Passwd in the section below
#               3. script requires GNU curl
#               4. script requires jq to parse json
#               5. Music directory's basename is 'music'. Otherwise need to modify sed command at line 131 below # WARNING! DEPENDS ON YOUR MUSIC DIRECTORY PATH
#
# External dependencies:
    source ./utils.sh
#                       - Awk
#                       - curl
# References:
#       -Offical Synology-API: https://global.download.synology.com/download/Document/DeveloperGuide/Surveillance_Station_Web_API_v2.0.pdf
#       -Forumthread: http://forum.synology.com/enu/viewtopic.php?f=82&t=47074&start=15
#       -Thanks to pat31 for his example-script: http://www.weblink.fr/camera-cmd
#
# Useful commands:
#
#/webapi/query.cgi?api=SYNO.API.Info&version=1&method=query&query=ALL        ou query=SYNO.API.Auth,,SYNO.AudioStation.
#/webapi/DownloadStation/info.cgi?api=SYNO.DownloadStation.Info&version=1&method=getinfo
#/webapi/DownloadStation/info.cgi?api=SYNO.DownloadStation.Info&version=1&method=getconfig
#http://myds.com:5000/webapi/auth.cgi?api=SYNO.API.Auth&version=2&method=login&account=admin&passwd=12345&session=DownloadStation&format=cookie


####################################
# TO CONFIGURE BEFORE USING SCRIPT #
####################################
# Synology user
SYNO_SS_USER="toto"
# Corresponding pwd
SYNO_SS_PASS="thePass"
# Syno server address
SYNO_URL="192.168.0.20:5001"
debug_mode=${debug_mode:-1}

#######################
# END OF CONFIGURATION
#######################

######################
# Internal variables #
######################
CURRENT_SESSION_ID=""

#############
# Functions #
#############
function _cleanupSession ()
{
 CURRENT_SESSION_ID=""
}

function _checkSynoResponse ()
{
  if [[ ! $1 =~ "\"success\":true}" ]]
  then
        echo "$2 failed: "$RESPONSE
        _cleanupSession
        exit -1
  fi
}

function usage {
  echo "USAGE: $0 -r ratingNumber [-p playlistDestinationDirectory] [-m music directory]
             -m : music directory to replace as absolute path in playlist
             -p: directory where to store generate playlist
             -r : rating number for the playlist to generate
             -h --help : Display this message
        "
  exit 0
}

function datacheck {
  [ $ratingNumber -lt 0 ] && { endProg 5 "No rating given in entry." ; }
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
  musicDirectory="$MUSIC_DIRECTORY_DEFAULT"
  playlistDirectory="$PLAYLIST_DIRECTORY_DEFAULT"
  ratingNumber=-1
  while getopts "m:p:r:h" option
  do
    case $option in
      h)
        usage
        ;;
      m)
        musicDirectory="$OPTARG";
        ;;
      p)
        playlistDirectory="$OPTARG";
        ;;
      r)
        ratingNumber="$OPTARG";
        ;;
      :)
        endProg 1 "Option $OPTARG needs an argument" ;
        ;;
      \?)
        endProg 1 "$OPTARG : invalid option" ;
        ;;
    esac
  done

  playlistFile="$playlistDirectory/$ratingNumber-stars.m3u"
  echo "Creating dynamic ranking playlist: $playlistFile"
}

### MAIN ####

initialize "$@"
datacheck

## 1.step login ##

VER=4
METHOD="Login"
echo "Login..."
#RESPONSE=`wget -q --keep-session-cookies --save-cookies $COOKIESFILE -O- "https://${SYNO_URL}/webapi/auth.cgi?api=SYNO.API.Auth&method=$METHOD&version=${VER}&account=${SYNO_SS_USER}&passwd=${SYNO_SS_PASS}&session=AudioStation&format=sid"`
#RESPONSE=`wget -qO - --save-cookies /volume1/@appstore/OpenRemote/scripts/cookies_ms.txt --post-data "api=SYNO.API.Auth&version=2&method=login&account=admin&passwd=12345&session=AudioStation&format=cookie" http://192.168.1.7:5000/webapi/auth.cgi`
#curl -v -i -o -k --data  --trace-ascii
RESPONSE=`curl -s -q -k --data "api=SYNO.API.Auth&method=$METHOD&version=${VER}&account=${SYNO_SS_USER}&passwd=${SYNO_SS_PASS}&session=AudioStation&format=sid" "https://${SYNO_URL}/webapi/auth.cgi"`
# example of reply : {"data":{"is_portal_port":false,"sid":"Y4hu1PHKVCeuk43B0LT2002589"},"success":true}
if grep -q -i "sid" <<< $RESPONSE; then
  CURRENT_SESSION_ID=`echo $RESPONSE | awk -F : '{print $4}'| cut -f2 -d'"' `
fi
_checkSynoResponse "$RESPONSE";

## 2.get playlist ##
echo "Get Songs with rating $ratingNumber..."
VER=2
METHOD="list"
#RESPONSE=`wget -q --load-cookies $COOKIESFILE -O- "http://${SYNO_URL}/webapi/SurveillanceStation/camera.cgi?api=SYNO.SurveillanceStation.Camera&method=$METHOD&version=$VER&cameraIds=$SYNO_CAMERAIDS"`
# To get more details in the response add these parameters:
# &limit=1000&additional=song_tag%2Csong_audio%2Csong_rating
RESPONSE=`curl -s -q -k --data "api=SYNO.AudioStation.Song&method=$METHOD&version=${VER}&library=all&limit=-1&song_rating_meq=$ratingNumber&song_rating_leq=$ratingNumber&sort_by=path&sort_direction=ASC&_sid=$CURRENT_SESSION_ID" "https://${SYNO_URL}/webapi/AudioStation/song.cgi"`
_checkSynoResponse "$RESPONSE";
numberOfSongs="`cat <<< "$RESPONSE" | jq '.data.total'`"
echo "Number of songs: $numberOfSongs"
# We overite the playlist if it exists
#echo "#EXTM3U" > "$playlistFile"
# Replace "/music/ by musicDirectory to have aboslute music paths and remove the " at the end
# WARNING! DEPENDS ON YOUR MUSIC DIRECTORY PATH
cat <<< "$RESPONSE" | jq ".data.songs[].path" | sed "s|\"\/music\/|${musicDirectory}\/|" | sed 's/.$//' > "$playlistFile"

## 3.step logout  ##
VER=4
METHOD="Logout"
#RESPONSE=`wget -q --load-cookies $COOKIESFILE -O- "http://${SYNO_URL}/webapi/auth.cgi?api=SYNO.API.Auth&method=$METHOD&version=${VER}"`
echo "Logout..."
RESPONSE=`curl -s -q -k --data "api=SYNO.API.Auth&method=$METHOD&version=${VER}&session=AudioStation&_sid=$CURRENT_SESSION_ID" "https://${SYNO_URL}/webapi/auth.cgi?"`
_checkSynoResponse "$RESPONSE";

## Cleanup ##
_cleanupSession

endProg 0
