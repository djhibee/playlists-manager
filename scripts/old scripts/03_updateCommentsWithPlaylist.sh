#!/bin/bash

# Synopsis:
#
# Update (add or remove) beets ratings for lossy and lossless file in a playlist
#  In case of add option and playlist is a rating list (e.g 5-stars.m3u.*), highest rating is kept and added only if not present
#
# Use two configurations and db, one for mp3 with lyrics, one for flac without lyrics
#   config_mp3.yaml -> library_mp3.db
#   config_lossless.yaml -> library_lossless.db
#
# Algo:
# For each file in the playlist
#   -> fetch  beets attributes
#         beet  -c $CONFIG_LOSSY list -f '$artist$}$album$}$title$}$mb_trackid' path:"$fileProper"
#   -> update playlist in lossy file comments
#         beet -c  $CONFIG_LOSSY modify -y  path:"$lossyFileFound" comments="$PlaylistName"
#   -> get corresponding flac file in $DIRECTORY_LOSSLESS
#   -> update playlist in lossless file comments
#       highest rating is kept if not already present
#       beet -c $CONFIG_LOSSLESS modify -y  path:"$fileToUpdate" comments="$PlaylistName"
#
# WARNING: Rating playlists must be named x-stars.m3u, i.e 5-stars.m3u
# WARNING: No space allowed in playlists! => because if [ ! -f $filePlaylist ]; failed otherwise
#
# usage: ./UpdateLosslessPLaylistsAndRatings playlist update-option (backup-file) , with update-option='add' or 'remove'
# default update option is add
# History
# Date            Version        Auteur        Commentaire
# 09//09/2016      1.0            Djhibee        Creation

CONFIG_LOSSY="/var/services/homes/djhibee/.config/beets/config.yaml"
CONFIG_LOSSLESS="/var/services/homes/djhibee/.config/beets/config-lossless.yaml"

FILE_PLAYLIST_DEFAULT="./toto.m3u"

countNotFoundFromPlaylist=0
debug_mode=0

#End of programme
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

# Controls
function controls {
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

# Add or remove the playlist from the file comments
function updateComments {
  fileToUpdate="$1"
  configToUse="$2"
  log "update comments with config $configToUse and option $updateOption"
  log "file to update: $fileToUpdate"
  oldComments="`beet -c $configToUse list path:"$fileToUpdate" -f '$comments'`"
  # Handle ../ in case the playlist path is absolute and not the current repo
  # ../foo/bar/playlist.m3u => playlist
  playlistRatingName=$(basename "$filePlaylist" ".m3u" | cut -f1 -d'.' )
  log "the playlist name is $playlistRatingName"

  if [ "$updateOption" = "remove" ]
  then
    # REMOVE OPTION CHOSEN
    log "Remove option confirmed"
    newComments="${oldComments//, $playlistRatingName/}"
    newComments="${oldComments//$playlistRatingName,/}"
    log "New comments :  $newComments"
    beet -c $configToUse modify -M -y  path:"$fileToUpdate" comments="$newComments"
  else
        # ADD OPTION CHOSEN by default
        if echo $oldComments | grep -i "$playlistRatingName"; then
          echo "Rating already embeded in comments"
        else
          log "Old comments : $oldComments"
          newComments="$oldComments, $playlistRatingName"
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
          beet -c $configToUse modify -M -y   path:"$fileToUpdate" comments="$newComments"
        fi
  fi

}

# Print not found file
function printNotFoundFile {
  losslessFileNotFound="$1"
  log "NOT FOUND lossless file for: $losslessFileNotFound"
  echo "$losslessFileNotFound" >> "$FILE_NOT_FOUND_IN_LOSSLESS"
  countNotFoundFromPlaylist=$((countNotFoundFromPlaylist + 1))
}

# Update backupFile with the file in order not to re-process it
# in case of a stop before the full parsing of the playlist
function printFoundLosslessFile {
  if [ "$updateOption" = "add" ]
  then
    echo "$file" >> "$backupFile"
  fi
}


echo "updateCommentsWithPlaylist started..."

if [ "$debug_mode" = 1 ]; then
  echo "debug mode is ON"
else
  echo "debug mode is OFF"
fi

echo "... Get parameters"

if [ $# -gt 0 ]; then
	filePlaylist="$1"
  updateOption="$2"
  backupFile="$3"
else
    filePlaylist=$FILE_PLAYLIST_DEFAULT
    updateOption="add"
fi

FILE_NOT_FOUND_IN_LOSSLESS="$filePlaylist.notFoundInLossless.txt"

echo "Processed playlist is: $filePlaylist"
echo "Chosen option is $updateOption"
echo "Backup file is $backupFile"
echo "Fichiers flac  non trouves dumpes dans  $FILE_NOT_FOUND_IN_LOSSLESS"

controls

# Replace \ by \\ and create a copy of the playlist to work on it
sed 's/\\/\\\\/g' $filePlaylist > $filePlaylist.tmp

echo "... Starting $filePlaylist.tmp processing"

while read file; do

  fileProper="$file"
  # uncomment when running on Macosx
  #fileProper="`iconv -f utf-8 -t utf-8-mac <<< "$file"`"
  log "Processing $fileProper"
  # get data from beet mp3 library
  # } must be escaped with $ (see beet doc)
  data=$(beet  -c $CONFIG_LOSSY list -f '$artist$}$album$}$title$}$mb_trackid' path:"$fileProper")
  log "data: $data"
  if [[ ! -z "$data" ]]
  then
    updateComments "$fileProper" $CONFIG_LOSSY
    IFS='}' read -r -a array <<< "$data"
    if [ -n "${array[3]}" ] && [ "${array[3]}" != "" ] && [ "${array[3]}" ]
    then
      # on cherche d'abord la chanson via son id musicbrainz
      echo "looking for musicbrainzid ${array[3]}"
      newPath_lossless=$(beet  -c $CONFIG_LOSSLESS list -p mb_trackid:"${array[3]}")
      if [[ ! -z "$newPath_lossless" ]]
      then
        #la chanson a ete trouve via musicbrainzid
        updateComments "$newPath_lossless" $CONFIG_LOSSLESS
        printFoundLosslessFile
        continue
      else
        #la chanson n'a pas ete trouvee, on cherche par album, artist et titre
        if [ -n "${array[2]}" ] && [ "${array[2]}" != "" ] && [ "${array[2]}" ]
        # il faut un titre sinon impossible de trouver
        then
          echo "looking for artist:${array[0]} album:${array[1]} title:${array[2]}"
          newPath_lossless=$(beet  -c $CONFIG_LOSSLESS list -p  album:"${array[1]}" artist:"${array[0]}" title:"${array[2]}")
          if [[ ! -z "$newPath_lossless" ]]
          then
            # la chanson a ete trouvee avec le bon album
            updateComments "$newPath_lossless" $CONFIG_LOSSLESS
            printFoundLosslessFile
            continue
          else
            # la chanson n a pas ete trouvee, on cherche seulement par artiste et titre
            # beet list peut retourner plusieurs tracks du coup
            echo "looking for artist:${array[0]} title:${array[2]}"
            beet  -c $CONFIG_LOSSLESS list -p  artist:"${array[0]}" "title::^${array[2]}$" > file_newPath_lossless.tmp
            filefound=false
            while read newPath_lossless; do
              if [[ ! -z "$newPath_lossless" ]]
              then
                # la chanson a ete trouvee
                updateComments "$newPath_lossless" $CONFIG_LOSSLESS
                printFoundLosslessFile
                filefound=true
                continue
              fi
            done < file_newPath_lossless.tmp
            if $filefound ; then
              echo "the file was found we continue the loop"
              continue
            fi
          fi
        fi
        # la chanson n a pas ete trouvee du tout
        printFoundLosslessFile
        printNotFoundFile "$fileProper"
        continue
      fi
    else
      #pas de musicbrainzid, on cherche directement par album, artist et titre
      if [ -n "${array[2]}" ] && [ "${array[2]}" != "" ] && [ "${array[2]}" ]
      # il faut un titre sinon impossible de trouver
      then
        echo "looking for artist:${array[0]} album:${array[1]} title:${array[2]}"
        newPath_lossless=$(beet  -c $CONFIG_LOSSLESS list -p  album:"${array[1]}" artist:"${array[0]}" title:"${array[2]}")
        if [[ ! -z "$newPath_lossless" ]]
        then
          # la chanson a ete trouvee avec le bon album
          updateComments "$newPath_lossless" $CONFIG_LOSSLESS
          printFoundLosslessFile
          continue
        else
          # la chanson n a pas ete trouvee, on cherche seulement par artiste et titre
          echo "looking for artist:${array[0]} title:${array[2]}"
          beet  -c $CONFIG_LOSSLESS list -p  artist:"${array[0]}" "title::^${array[2]}$" > file_newPath_lossless.tmp
          filefound=false
          while read newPath_lossless; do
            if [[ ! -z "$newPath_lossless" ]]
            then
              # la chanson a ete trouvee
              updateComments "$newPath_lossless" $CONFIG_LOSSLESS
              printFoundLosslessFile
              filefound=true
              continue
            fi
          done < file_newPath_lossless.tmp
          if $filefound ; then
            echo "the file was found we continue the loop"
            continue
          fi
        fi
      fi
      # la chanson n a pas ete trouvee du tout
      printNotFoundFile "$fileProper"
      printFoundLosslessFile
      continue
    fi
  else
    echo "$fileProper"
    printf " was not found in DB\n"
    printNotFoundFile "$fileProper"
    countNotFoundFromPlaylist=$((countNotFoundFromPlaylist + 1))
  fi

done < "$filePlaylist.tmp"

echo "number of files not found from playlist: $countNotFoundFromPlaylist"

# Clean files
if [ "$debug_mode" = 0 ]; then
#  rm -f "$FILE_NOT_FOUND_IN_LOSSLESS"
  rm -f "$filePlaylist.tmp"
fi

endProg 0
