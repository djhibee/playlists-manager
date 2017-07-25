#!/bin/bash
# May be easily converted to sh compatible script if needed, since a very few bashisms are used ([[]]...)
#
# Synopsis :
#       Lowest level script.
#       Add or remove the playlist in Beets' comments for a song (lossy or lossless).
#       In case of add option and playlist is a rating list (e.g 5-stars.m3u.*), highest rating is kept in Beets' comments.
#       This means that you have to process rating playlists by decreasing order (from 5 stars to 1 stars).
#       Insert also file in SQLite DB PLAYLISTS table to persist playlists and improve performances.
#
# Usage:
#            Run command ./updateFileComments.sh --help
#
# Return codes:
#             0: Everything went fine
#             1: Wrong usage of the command
#             300: $songPath is not a file
#             400: No id was found in FILES table for file $songPath
#             500: songPlayListOrder does not correspond to file $songPath in DB
#             900: update operation is not add or remove
#
#
# WARNING CONVENTION: Rating playlists must be named x-stars.m3u, i.e 5-stars.m3u
# WARNING LIMITATION: handle only mp3 for Lossy files and flac/m4a for lossless ones => easy to change
#
# Pre-requisites:
#   songPath should be present in SQLite DB FILE table
#   Rating playlists must be named x-stars.m3u, i.e 5-stars.m3u
#   By definition, a song can't be present in two different rating playlists, and is present only once in these...
#   beets library available (linK: http://beets.io/)
#   Use two beets configurations and databases, one for mp3 with lyrics, one for flac without lyrics
#   config_mp3.yaml -> library_mp3.db
#   config_lossless.yaml -> library_lossless.db
#
#
# External dependencies:
    source ./utils.sh
#   SQLite DB created according to the structure below
#   sed command
#
# Algo:
#   -> identify the quality of the file
#   -> update playlist in file beets comments
#       highest rating is kept if not already present
#       beet -c  $CONFIG modify -y  path:"$fileFound" comments="$PlaylistName"
#   -> update playlist in DB
#
# History
# Date            Version        Auteur        Commentaire
# 06/11/2016      1.0            Djhibee       Creation
# 13/03/2017      2.0            Djhibee       Total refactoring

####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################
# Temporary file where some DB requests' results will be stored
DB_REQUEST_RESULT_TMP_FILE="updateFileCOmments_DB_results.txt"
debug_mode=${debug_mode:-1}
#######################
# END OF CONFIGURATION
#######################
#########################
## Other variables
#########################
### Global variables ###
ADD_OPTION=${ADD_OPTION:-"add"}
REMOVE_OPTION=${REMOVE_OPTION:-"remove"}

### Constants ###

usage="USAGE: $0 [-hcd] -s songPath -p playlistName [-u updateOperation] [-r songPlayListRank]

           -c : store playlist in file comments
           -d : store playlist in SQLITE DB (advised). Doesn't work with rating playlists
           -h --help : Display this message
           -p playlistName : playlist to update
           -r songPlayListRank: Rank of the song in the playlist.
                              Default value if not provided: 0
                               <0 :
                                  -> $REMOVE_OPTION operation: remove all occurences of the song
                                  -> $ADD_OPTION operation:  add the song at the end of the playlist
                               = 0 :
                                  -> $REMOVE_OPTION operation: remove the last occurence of the song
                                  -> $ADD_OPTION operation:  add the song at the end of the playlist
                               > 0 :
                                 -> $REMOVE_OPTION operation: remove one occurence of the song at rank specified
                                 -> $ADD_OPTION operation: add one occurence of the song at rank specified
           -s : original song file to update
           -u updateOperation :
                    \"add\"  to add playlist in songs' Beets comments
                    \"remove\" to remove  playlist from song's Beets comments

      "

function datacheck {
    # TODO Uncomment when files are ready
    #[ ! -f "$fileToUpdate" ] && { endProg 300 ": $fileToUpdate is not a file." ; }
    [[ ( -z "${fileToUpdate// }" ) || ( -z "${playlistName// }" ) ]] && { endProg 1 ": song file and playlist name are mandatory parameters (see --help) " ; }
    [ $updateOperation != "$REMOVE_OPTION" ] && [ $updateOperation != "$ADD_OPTION" ] && { endProg 900 ": update operation can only be \"$ADD_OPTION\" or \"$REMOVE_OPTION\" (see --help) " ; }
    [[ ! -z "$isRatingPlaylist" ]] && [[ $updateDB -eq 1 ]] && { updateDB=0 ; echo "Update DB option forced to 0 because $playlistName is a rating playlist." ; }
}

# Set global attributes and log few pieces of info
function initialize {
  if [ "$debug_mode" -eq 1 ]; then
    echo "debug mode is ON"
  else
    echo "debug mode is OFF"
  fi
  if [[ $1 =~ ^-h|--help ]]; then
    echo "$usage"
    echo
    exit
  fi
  playlistName=""
  updateOperation=$ADD_OPTION
  updateComments=0
  updateDB=0
  songPlayListOrder=0
  while getopts "cdhp:r:s:u:" option
  do
    case $option in

      c)
        updateComments=1
        ;;
      d)
        updateDB=1
        ;;
      h)
        usage
        ;;
      p)
        playlistName="$OPTARG";
        ;;
      r)
        songPlayListOrder="$OPTARG";
        ;;
      s)
        fileToUpdate="$OPTARG";
        ;;
      u)
        updateOperation="$OPTARG";
        ;;
      :)
        endProg 1 "Option $OPTARG needs an argument" ;
        ;;
      \?)
        endProg 1 "$OPTARG : invalid option" ;
        ;;
    esac
  done

  # important to trim files from \r and \n !!!!!
  fileToUpdate=$(echo $fileToUpdate| tr -d '\n' | tr -d '\r' )
  log "File to update: $fileToUpdate"
  log "Playlist: $playlistName"
  log "update operation: $updateOperation"
  log "update file comments?: $updateComments"
  log "updateDB?: $updateDB"
  log "songPlayListOrder: $songPlayListOrder"

  ##################################
  # identify the file music quality
  ##################################

  fileQuality="LOSSY"
  configToUse=$CONFIG_LOSSY
  if echo "$fileToUpdate" | grep -i 'flac\|m4a' > /dev/null ; then
    fileQuality="LOSSLESS"
    configToUse=$CONFIG_LOSSLESS
  fi
  log "quality: $fileQuality"

  # identify the type of playlist
  isRatingPlaylist=`echo $playlistName | grep -e '[54321]-stars'`
}

# Add or remove the playlist from the file comments and/or DB
function addOrRemoveSongFromPlaylist {

  oldComments="`beet -c $configToUse list path:"$fileToUpdate" -f '$comments'`"
  log "oldComments: $oldComments"
  if [ "$updateOperation" = "$REMOVE_OPTION" ]
  then
    log "Remove operation confirmed"
    if [ $updateComments -eq 1 ]
    then
      # remove from comments
      log "Update comments with config $configToUse and option $updateOperation"
      if [[ $songPlayListOrder -gt -1 ]]
      then
        # we remove only one occurence of the song from Beet's comments
        newComments="${oldComments/$playlistName/}"
        # clean comments by removing potential ,,
        echo $toto | sed -e 's/, *,/,/g'
        newComments=`echo $newComments | sed -e 's/, *,/,/g'`
      else
        # we use global substitution (double slash) to replace all occurences
        newComments="${oldComments//$playlistName/}"
        # clean comments by removing potential ,,
        newComments=`echo $newComments | sed -e 's/, *,/,/g'`
      fi
      log "$oldComments =>  $newComments"
      beet -c $configToUse modify -M -y  path:"$fileToUpdate" comments="$newComments"
    fi

    if [[ $updateDB -eq 1 ]]
    then
      #remove from DB
      if [[ $songPlayListOrder -gt 0 ]]
      then
        # delete only the specified occurence
        # check that the song we want to delete at playorder is really the one from the fileToUpdate
        getFilePathDBRequest="SELECT $fileQuality
                              FROM FILES AS f
                              JOIN PLAYLISTS as p
                              ON f.ID=p.TRACKID
                              WHERE p.PLAYORDER = $songPlayListOrder
                              AND p.PLAYLISTNAME=$playlistName
                              ;"
        filePathInDB=`sqlite3 $SQLITEDB <<< "$getFilePathDBRequest"`
        if [ "$filePathInDB" != "$fileToUpdate" ]
        then
          endProg 500 "songPlayListOrder does not correspond to file $fileToUpdate in DB but to file $filePathinDB."
        fi
        deleteDBRequest="DELETE
                         FROM PLAYLISTS
                         WHERE PLAYLISTNAME =\"$playlistName\"
                         AND PLAYORDER = $songPlayListOrder
                         ;"

        log "$deleteDBRequest"
        sqlite3 $SQLITEDB <<< "$deleteDBRequest"

      elif [[ $songPlayListOrder -eq 0 ]]
      then
        # delete only the last occurence of the song
        # check that the song we want to delete is really part of the playlist
        maxOrderDBRequest="SELECT MAX(PLAYORDER)
                             FROM PLAYLISTS AS P
                             WHERE p.PLAYLISTNAME=\"$playlistName\"
                             AND TRACKID IN
                               (SELECT ID
                                FROM FILES
                                WHERE $fileQuality=\"$fileToUpdate\"
                               )
                             ;"
        maxOrder=`sqlite3 $SQLITEDB <<< "$maxOrderDBRequest"`
        if [ -z "$maxOrder" ]
        then
          echo "WARNING: File $fileToUpdate is not part of playlist $playlistName in DB."
        else
          deleteDBRequest="DELETE
                           FROM PLAYLISTS
                           WHERE PLAYLISTNAME =\"$playlistName\"
                           AND PLAYORDER =\"$maxOrder\"
                           ;"
          log "$deleteDBRequest"
          sqlite3 $SQLITEDB <<< "$deleteDBRequest"
        fi
      else
        # delete all occurences
        # get song ID from FILES table in SQLite DB
        # Because of partial matches, a song file can have several IDS
        getMainIDDBRequest="SELECT ID
                            FROM FILES
                            WHERE $fileQuality=\"$fileToUpdate\"
                            ;"
        sqlite3 $SQLITEDB <<< "$getMainIDDBRequest" > "$DB_REQUEST_RESULT_TMP_FILE"

        if [[ ! -s $DB_REQUEST_RESULT_TMP_FILE ]] ; then
          endProg 400 "Unexpected error occured. No id was found in FILES table for file $fileToUpdate"
        else
          while read songIDinDB; do
            deleteDBRequest="DELETE
                             FROM PLAYLISTS
                             WHERE PLAYLISTNAME =\"$playlistName\"
                             AND TRACKID = \"$songIDinDB\"
                             ;"
            log "$deleteDBRequest"
            sqlite3 $SQLITEDB <<< "$deleteDBRequest"
          done < "$DB_REQUEST_RESULT_TMP_FILE"
        fi
      fi
    fi

  else   # ADD OPTION CHOSEN by default
    log "Add operation confirmed"

    if [ $updateComments -eq 1 ]
    then
      log "Update comments with config $configToUse and option $updateOperation"
      isRatingPresentInComments=`echo $oldComments | grep -e "$playlistName"`
      # dont add ratings more than once in the beet's comments
      if [[ ! -z "$isRatingPlaylist" ]] && [[ ! -z "$isRatingPresentInComments" ]]
      then
        log "Rating already stored in Beet's comments. No need to add it."
        newComments="$oldComments"
      else
        newComments="$oldComments, $playlistName"
      fi
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
      log "New comments:  $newComments"
      beet -c $configToUse modify -M -y   path:"$fileToUpdate" comments="$newComments"
    fi

    if [[ $updateDB -eq 1 ]]
    then
      # get song ID from FILES table in SQLite DB
      # reminder: By construction of FILES table, an orphan cannot exist if a match (perfect or partial) exists
      # So we still give the priority to the entry corresponding to a full match
      getMainIDDBRequest="SELECT ID
                          FROM FILES
                          WHERE $fileQuality=\"$fileToUpdate\"
                          ORDER BY MATCH_TYPE ASC
                          LIMIT 1
                          ;"
      songIDinDB=`sqlite3 $SQLITEDB <<< "$getMainIDDBRequest"`
      if [[ -z "$songIDinDB" ]]
      then
        endProg 400 "Unexpected error occured. No id was found in FILES table for file $fileToUpdate"
      fi
      if [[ $songPlayListOrder -lt 1 ]]
      then
        # add the song at the end of the playlist
        maxOrderDBRequest="SELECT coalesce(
                                     ( SELECT max(PLAYORDER)+1 FROM PLAYLISTS
                                       WHERE PLAYLISTNAME =\"$playlistName\"
                                      ) ,
                                     1
                                   )
                           ;"
        songPlayListOrder=`sqlite3 $SQLITEDB <<< "$maxOrderDBRequest"`
      fi

      # add file in SQL DB playlist
      # Either update the current playlist song at the current play order or create a new entry
      echo " DB Insert or replace: $fileToUpdate in $playlistName at rank $songPlayListOrder "
      addDBRequest="INSERT OR REPLACE
                    INTO PLAYLISTS (PLAYLISTNAME, PLAYORDER, TRACKID)
                    VALUES (\"$playlistName\", \"$songPlayListOrder\", \"$songIDinDB\" )
                    ;"
      sqlite3 $SQLITEDB <<< "$addDBRequest"
    fi
  fi
}

echo "...$0 script started..."
# "" are mandatory otherwise parameters will be split by space
initialize "$@"
datacheck
addOrRemoveSongFromPlaylist
if [ "$debug_mode" -eq 0 ]; then
  rm -f "$DB_REQUEST_RESULT_TMP_FILE"
fi
endProg 0
