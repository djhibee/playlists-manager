#!/bin/sh

# !!! DRAFT !!!! But working...
# Keep highest rating in Beets' comments for files in given playlist.
#

CONFIG_MUSIC="/Users/superToto/.config/beets/config.yaml"
FILE_PLAYLIST_DEFAULT="./toto.m3u"
debug_mode=1

RED_COLOR=${RED_COLOR:-'\033[0;31m'}
NO_COLOR=${NO_COLOR:-'\033[0m'}
LOG_COLOR_DEFAULT=${LOG_COLOR_DEFAULT:-$NO_COLOR}

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

if [ $# -gt 0 ]; then
	filePlaylist=$1
else
  filePlaylist=$FILE_PLAYLIST_DEFAULT
fi

echo "Default playlist is: $FILE_PLAYLIST_DEFAULT"
echo "Processed playlist is: $filePlaylist"
if [ "$debug_mode" = 1 ]; then
  echo "debug mode is ON"
else
  echo "debug mode is OFF"
fi

# Replace \ by \\
sed 's/\\/\\\\/g' $filePlaylist > $filePlaylist.tmp
sed "s/$(printf '\r')//" $filePlaylist.tmp > $filePlaylist.tmp.bak
#sed -i.bak "s/$(printf '\r')//" $filePlaylist.tmp

echo "... Starting $filePlaylist.tmp processing"

while read file; do
  echo "Processing $file"
  oldComments="`beet -c $CONFIG_MUSIC list path:"$filePath" -f '$comments'`"
  log "Old comments : $oldComments"
  newComments="$oldComments"
  # in case of star rating, just keep the highest
  # 5-stars, 2-stars => 5-stars
  # 2-stars, 5stars => 5-stars
  # 5-stars, summer, 2-stars => 5-stars, summer
  # 2-stars, summer, 5-stars => summer, 5-stars
  # summer, 2-stars, 5-stars => summer, 5-stars
  # summer, 5-stars, 2-stars => summer, 5-stars
  # summer, 2-stars, chorus, 5-stars => summer, chorus, 5-stars
  case "$newComments" in
    # double slash means global substitution to replace all occurences
  *5-stars*)
    newComments="${newComments//,[4321]-stars/}"
    newComments="${newComments//[4321]-stars,/}"
    ;;
  *4-stars*)
    newComments="${newComments//,[321]-stars/}"
    newComments="${newComments//[321]-stars,/}"
    ;;
  *3-stars*)
    newComments="${newComments//,[21]-stars/}"
    newComments="${newComments//[21]-stars,/}"
    ;;
  *2-stars*)
    newComments="${newComments//,[1]-stars/}"
    newComments="${newComments//[1]-stars,/}"
    ;;
  *1-stars*)
    newComments="$newComments"
    ;;
  esac
  log "New comments :  $newComments"

  beet -c $CONFIG_MUSIC modify -y  path:"$filePath" comments="$newComments"

done < "$filePlaylist"
exit 0
