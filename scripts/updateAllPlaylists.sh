#!/bin/bash
# May be easily converted to sh compatible script if needed, since a very few bashisms are used ([[]]...)
#
# Synopsis:
#       Highest level script.
#       Backup lossy playlists from Synology server and regenerate corresponding best quality ones.
#       Update files Beets' comments accordingly.
#       Use a SQLite DB to store playlists
#
# Usage: bash ./updateAllPlaylists.sh -h
#
# Pre-requisites:
#   Playlist can use either relatives or absolutes paths to identify the songs
#   Pool of playlist must be available.
#   WARNING CONVENTION: Rating playlists must be named x-stars.m3u, i.e 5-stars.m3u
#   WARNING LIMITATION: handle only mp3 for Lossy files and flac/m4a for lossless ones => easy to change
#   NOTE : This script should handle multi quality playlist for non ranking ones (not tested)
#
## External dependencies:
    source ${BASH_SOURCE%/*}/../SETTINGS
    source ${BASH_SOURCE%/*}/utils.sh
#   generateRatingPlaylist.sh
#   updatePlaylist.sh
#   sed and comm commands
#   SQLite DB created according to the structure in createSQLiteDB.sql
#
#
# Algo:
# Get all playlists in PLAYLIST_DIRECTORY_TO_BACKUP
#   -> regenerate rating playlists from Synology API
# For each playlist
#   -> get previous playlist from SQLITE DB or beets if it's a ranking playlist
#   -> Backup previous playlist to BACKUP_DIRECTORY
#   -> compare both files
#       -> if changes are complex (modification not at the end), regenerate the full playlist
#       -> otherwise
#         -> put new files in $playlist.addedSinceLastBackup
#         -> put removed files in $playlist.removedSinceLastBackup
#         -> add new files to DB playlist and update beet comments
#           -> ./updatePlaylist.sh $playlist.addedSinceLastBackup add
#         -> remove old files from DB playlist and update beet comments
#           -> ./updatePlaylist.sh $playlist.removedSinceLastBackup remove
#       -> regenerate max quality and min quality playlists in GENERATED_PLAYLIST_DIRECTORY after backup of old one
#
#
# Useful commands:
#     timestamp="$(date +'%Y%m%d%H%M')";while read playlist; do cp "$playlist" "./backups/$timestamp-$playlist"; done <  <(find *.m3u)
#
# History
# Date            Version        Auteur        Commentaire
# 11/09/2016      1.0            Djhibee       Creation
# 16/03/2017      2.0            Djhibee       Introduce SQLITE DB

####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################

debug_mode=${debug_mode:-0}

#######################
# END OF CONFIGURATION
#######################
#######################
## Other variables
#######################


##############################################
function usage {
  echo "USAGE: $0 [-hl]
             -h --help : Display this message
             -l : try to match by artist and title in last chance match for pair songs
        "
  exit 0
}

function initialize {
  if [[ $1 =~ ^--help ]]; then
    usage
  fi
  echo "$0 script started..."
  if [ "$debug_mode" -eq 1 ]; then
    echo "Debug mode is ON"
  else
    echo "Debug mode is OFF"
  fi
  useLastChanceMatch=0
  useLastChanceMatchOption=""
  while getopts "hl" option
  do
    case $option in
      h)
        usage
        ;;
      l)
        useLastChanceMatch=1
        useLastChanceMatchOption="-l"
        ;;
      :)
        endProg 1 "Option $OPTARG needs an argument" ;
        ;;
      \?)
        endProg 1 "$OPTARG : invalid option" ;
        ;;
    esac
  done
  log "Las chance match option is set to $useLastChanceMatch"

  [ ! -d "$PLAYLIST_DIRECTORY_TO_BACKUP" ] && { mkdir "$PLAYLIST_DIRECTORY_TO_BACKUP" ; }
  [ ! -d "$BACKUP_DIRECTORY" ] && { mkdir "$BACKUP_DIRECTORY" ; }
}


##########
#  Main
##########
initialize "$@"
echo "Starting update of playlists in $PLAYLIST_DIRECTORY_TO_BACKUP..."

# Get dynamic rating playlists from AudioStation
#for i in `seq 1 5`
#do
#  $GENERATE_RATING_PLAYLIST_SCRIPT_PATH -r "$i" -p "$PLAYLIST_DIRECTORY_TO_BACKUP"
#done

# filter only .m3u file from given PLAYLIST_DIRECTORY_TO_BACKUP
PLAYLISTS_FILE="$TMP_DIRECTORY/playlists.tmp"
find $PLAYLIST_DIRECTORY_TO_BACKUP -maxdepth 1 |  grep .m3u$ > "$PLAYLISTS_FILE"
timestamp="$(date +'%Y%m%d%H%M')"
[ ! -d "$BACKUP_DIRECTORY/$timestamp" ] && { mkdir "$BACKUP_DIRECTORY/$timestamp" ; }

while read filePlaylist; do
	echo "...Processing Playlist $filePlaylist..."
  # Handle ../ in case the playlist path is absolute and not the current repo
  # ../foo/bar/playlist.m3u => playlist
  playlistName=$(basename "$filePlaylist" ".m3u" | cut -f1 -d'.' )
  isRatingPlaylist=`echo $playlistName | grep -e '[54321]-stars'`

  ### Prepare backup playlist file
  newBackup="$BACKUP_DIRECTORY/$timestamp/$timestamp-$playlistName.m3u"
  echo "Previous $playlistName is backuped in $newBackup"

  # Since rating playlists are not stored in DB, we create them from beets
  if [[ -n "$isRatingPlaylist" ]]
  then
    echo "$playlistName is a rating playlist. No storage will be done in DB table."
    beet -c $CONFIG_LOSSY list -p "comments:$playlistName"  > "$newBackup"
  else
    # we create the backup file from th DB
    selectDBRequest="SELECT CASE WHEN LOSSY != \"\" THEN LOSSY ELSE LOSSLESS END
                     FROM FILES as f
                     INNER JOIN PLAYLISTS as p
                     ON f.ID=p.TRACKID
                     WHERE p.PLAYLISTNAME = \"$playlistName\"
                     ORDER BY p.PLAYORDER
                     ;"
    sqlite3 $SQLITEDB <<< "$selectDBRequest" > "$newBackup"
  fi
  # THAT STEP IS VERY IMPORTANT otherwise comm wont match lines between unix and windows encoded lines
  # indeed the command 'file' return 201609171402-2-stars.m3u.sorted: ASCII text, with CRLF line terminators
  # and 2-stars.m3u.sorted: ASCII text
  # so we remove the \r from the unix playlist
  cat "$newBackup" | tr -d '\r' | sed '/^\s*$/d' > "$newBackup.cleaned"
  sort "$newBackup.cleaned"  > "$newBackup.sorted"
  ### END OF Backup preparation

  ### Playlist preparation
  cat "$filePlaylist" | tr -d '\r' > "$filePlaylist.tmp"
  # Replace ../ by LOSSY_DIRECTORY to have aboslute music paths
  sed "s|\.\.\/|${LOSSY_DIRECTORY}\/|" "$filePlaylist.tmp" | sed '/#EXTINF:/d' | sed '/^\s*$/d' > "$filePlaylist.cleaned"
  sort "$filePlaylist.cleaned"  > "$filePlaylist.sorted"
  ### End of playlist preparation

  if [[ -n "$isRatingPlaylist" ]]
  then
    # we dont care of the order for rating playlist, hence the sort...
    comm -2 -3 "$filePlaylist.sorted" "$newBackup.sorted"  > "$filePlaylist.addedSinceLastBackup"
    comm -1 -3 "$filePlaylist.sorted" "$newBackup.sorted"  > "$filePlaylist.removedSinceLastBackup"
    isNewSongsAdded="`cat "$filePlaylist.addedSinceLastBackup" | grep -i 'mp3\|flac\|m4a' `"
    isSongsRemoved="`cat \"$filePlaylist.removedSinceLastBackup\" | grep -i 'mp3\|flac\|m4a' `"

    if [ -z "$isNewSongsAdded" ] && [ -z "$isSongsRemoved" ]
    then
        echo "No changed occured for $filePlaylist since last backup."
        rm -f "$newBackup"
    elif [ -n "$isNewSongsAdded" ]
    then
        echo "The `wc -l < \"$filePlaylist.addedSinceLastBackup\"` song(s) added since last backup:"
        cat "$filePlaylist.addedSinceLastBackup" | sed 's/^/     /'
        # we dont use the -o option since the given playlist is a diff and not the complete one
        $UPDATE_MUSIC_FILES_AND_SQLDB_SCRIPT_PATH $useLastChanceMatchOption -p "$filePlaylist.addedSinceLastBackup" -u "add" |  sed 's/^/     /'
    else
        echo "The `wc -l < \"$filePlaylist.removedSinceLastBackup\"` song(s) removed since last backup:"
        cat "$filePlaylist.removedSinceLastBackup" | sed 's/^/     /'
        $UPDATE_MUSIC_FILES_AND_SQLDB_SCRIPT_PATH $useLastChanceMatchOption -p "$filePlaylist.removedSinceLastBackup" -u "remove" |  sed 's/^/     /'
        # erase removed lignes from backup in order not to process it again next time
        #sort "$newBackup" | tr -d '\r' > "$newBackup.sorted"
        #comm -1 -3 "$filePlaylist.removedSinceLastBackup" "$newBackup.sorted" > "$newBackup"
    fi

  else
    echo "Check if songs order changed..."
    ####
    # Check if order of songs changed or if we just added/removed songs at the end of the playlist.
    # In the last case (most common), we can avoid a full playlist overwrite and so improve perfs.
    backupLength=`wc -l < "$newBackup.cleaned" | sed -e 's/^[ \t]*//'`
    playlistLength=`wc -l < "$filePlaylist.cleaned" | sed -e 's/^[ \t]*//'`
    minLenght=$(($backupLength<$playlistLength?$backupLength:$playlistLength))
    comm -3 <(head -n $minLenght "$filePlaylist.cleaned") <(head -n $minLenght "$newBackup.cleaned") > "$filePlaylist.checkOrderChange"
    if [[ -s "$filePlaylist.checkOrderChange" ]] ; then
      echo "Playlist song orders changed, we need to rebuild the full playlist"
      $UPDATE_MUSIC_FILES_AND_SQLDB_SCRIPT_PATH $useLastChanceMatchOption -p "$filePlaylist.cleaned" -u "add" -d -o |  sed 's/^/     /'
    else
      if [ $backupLength -eq $playlistLength ]
      then
          echo "No changed occured for $filePlaylist since last backup."
          rm -f "$newBackup"
      else
          echo "Playlist changes were at the end of the file, no need to rebuild the full playlist"
          if [ $minLenght -eq $backupLength ]
          then
            newSongsLines=$((playlistLength-backupLength))
            tail -n $newSongsLines "$filePlaylist.cleaned" > "$filePlaylist.addedSinceLastBackup"
            echo "$newSongsLines song(s) added since last backup: "
            cat "$filePlaylist.addedSinceLastBackup" | sed 's/^/     /'
            # we dont use the -o option since the given playlist is a diff and not the complete one
            $UPDATE_MUSIC_FILES_AND_SQLDB_SCRIPT_PATH $useLastChanceMatchOption -p "$filePlaylist.addedSinceLastBackup" -u "add" -d | sed 's/^/     /'
          else
            newSongsLines=$((backupLength-playlistLength))
            tail -n $newSongsLines "$newBackup.cleaned" > "$filePlaylist.removedSinceLastBackup"
            echo "$newSongsLines song(s) removed since last backup: "
            cat "$filePlaylist.removedSinceLastBackup" | sed 's/^/     /'
            $UPDATE_MUSIC_FILES_AND_SQLDB_SCRIPT_PATH $useLastChanceMatchOption -p "$filePlaylist.removedSinceLastBackup" -u "remove" -d | sed 's/^/     /'
          fi
      fi
    fi
  fi

  ######################
  # regenerate playlists
  ######################
  [ ! -d "$GENERATED_PLAYLIST_DIRECTORY" ] && { mkdir "$GENERATED_PLAYLIST_DIRECTORY" ; }

  # create a "BEST QUALITY playlist"
  # backup of old playlist
  if (test -e "$GENERATED_PLAYLIST_DIRECTORY/$playlistName.bestQuality.m3u")
  then
    echo "Backup best quality playlist"
    mv -f "$GENERATED_PLAYLIST_DIRECTORY/$playlistName.bestQuality.m3u" "$GENERATED_PLAYLIST_DIRECTORY/$playlistName.bestQuality.m3u.bak"
  fi
  echo "Create new best quality playlist: $GENERATED_PLAYLIST_DIRECTORY/$playlistName.bestQuality.m3u"
  echo "#EXTM3U" > "$GENERATED_PLAYLIST_DIRECTORY/$playlistName.bestQuality.m3u"

  # create new playlist
  if [[ -z "$isRatingPlaylist" ]]
  then
    selectDBRequest="SELECT CASE WHEN LOSSLESS != \"\" THEN LOSSLESS ELSE LOSSY END AS song
                       FROM FILES AS f
                       JOIN PLAYLISTS AS p ON f.ID=p.TRACKID
                       WHERE p.PLAYLISTNAME=\"$playlistName\"
                       ORDER BY PLAYORDER ASC
                       ; "
    sqlite3 $SQLITEDB <<< "$selectDBRequest" >> "$GENERATED_PLAYLIST_DIRECTORY/$playlistName.bestQuality.m3u"
  fi


  # create a "MIN QUALITY playlist"
  # backup of old playlist
  if (test -e "$GENERATED_PLAYLIST_DIRECTORY/$playlistName.minQuality.m3u")
  then
    echo "Backup min quality playlist"
    mv -f "$GENERATED_PLAYLIST_DIRECTORY/$playlistName.minQuality.m3u" "$GENERATED_PLAYLIST_DIRECTORY/$playlistName.minQuality.m3u.bak"
  fi
  echo "Create new min quality playlist: $GENERATED_PLAYLIST_DIRECTORY/$playlistName.minQuality.m3u"
  echo "#EXTM3U" > "$GENERATED_PLAYLIST_DIRECTORY/$playlistName.minQuality.m3u"

  # create new playlist
  if [[ -z "$isRatingPlaylist" ]]
  then
    selectDBRequest="SELECT CASE WHEN LOSSY != \"\" THEN LOSSY ELSE LOSSLESS END AS song
                       FROM FILES AS f
                       JOIN PLAYLISTS AS p ON f.ID=p.TRACKID
                       WHERE p.PLAYLISTNAME=\"$playlistName\"
                       ORDER BY PLAYORDER ASC
                       ; "
    sqlite3 $SQLITEDB <<< "$selectDBRequest" >> "$GENERATED_PLAYLIST_DIRECTORY/$playlistName.minQuality.m3u"
  else
    while read songFile; do
      if echo "$songFile" | grep -i 'mp3\|flac\|m4a' | grep -i -v '#recycle\|@eaDir' > /dev/null ; then
        ### identify the file music quality###
        mainFileQuality="LOSSY"
        if echo "$mainFile" | grep -i 'flac\|m4a' > /dev/null ; then
          mainFileQuality="LOSSLESS"
        fi
        selectDBRequest="SELECT CASE WHEN LOSSLESS != \"\" THEN LOSSLESS ELSE LOSSY END
                           FROM FILES
                           WHERE $mainFileQuality=\"$songFile\"
                           ORDER BY MATCH_TYPE ASC
                           LIMIT 1
                           ; "
        sqlite3 $SQLITEDB <<< "$selectDBRequest" >> "$GENERATED_PLAYLIST_DIRECTORY/$playlistName.bestQuality.m3u"

        selectDBRequest="SELECT CASE WHEN LOSSY != \"\" THEN LOSSY ELSE LOSSLESS END
                           FROM FILES
                           WHERE $mainFileQuality=\"$songFile\"
                           ORDER BY MATCH_TYPE ASC
                           LIMIT 1
                           ; "
        sqlite3 $SQLITEDB <<< "$selectDBRequest" >> "$GENERATED_PLAYLIST_DIRECTORY/$playlistName.minQuality.m3u"
      fi
    done < "$filePlaylist"
  fi

  # Clean files
  if [ "$debug_mode" = 0 ]; then
    rm -f "$filePlaylist.addedSinceLastBackup"
    rm -f "$filePlaylist.removedSinceLastBackup"
    rm -f "$newBackup.cleaned"
    rm -f "$filePlaylist.cleaned"
    rm -f "$filePlaylist.tmp"
    rm -f "$filePlaylist.checkOrderChange"
    rm -f "$filePlaylist.sorted"
    rm -f "$newBackup.sorted"
  fi

  echo "###################"
  echo "###################"
  echo "###################"

done < "$PLAYLISTS_FILE"

# creationDate=`echo $playlist|awk -F _ '{print $1$2}'|sed 's/h//g'`
# backup Quality playlists  to QUALITY_BACKUP_DIRECTORY
#echo "Backup quality playlist repo"
#[ ! -d "$QUALITY_BACKUP_DIRECTORY" ] && { mkdir "$QUALITY_BACKUP_DIRECTORY" ; }
#cp -a "$GENERATED_PLAYLIST_DIRECTORY" "$QUALITY_BACKUP_DIRECTORY/playlists-$timestamp"
#delete useless @eadir direcotries
#find "$QUALITY_BACKUP_DIRECTORY/playlists-$timestamp" -type d -name "@eaDir" -print0 | xargs -0 rm -rf

# Clean files
if [ "$debug_mode" -lt 1 ]; then
  rm -f "$PLAYLISTS_FILE"
fi

echo "All Playlists were updated successfully".
endProg 0
