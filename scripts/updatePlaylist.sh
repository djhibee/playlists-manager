#!/bin/bash
# May be easily converted to sh compatible script if needed, since a very few bashisms are used ([[]]...)

# Synopsis :
#     Medium level script.
#     Add or remove the playlist name in Beets' comments for all songs (lossy or lossless)
#     AND their corresponding pair (respectively lossless or lossy) from a playlist.
#     Insert also files in a SQLite DB  to persist playlists and improve performances.
#     In case of add option and playlist is a rating list (e.g 5-stars.m3u.*), highest rating is kept in Beets' comments.
#     Ranking playlists are not maintained in DB.
#
# Usage: Run command ./updatePlaylist.sh --help
#
# Return codes:
#             0: Everything went fine
#             1: Wrong usage of the command
#             200: $playlistFile is not a file
#             300: overwrite option can only be used with ADD_OPTION
#             900: update option is not add or remove
#
# Pre-requisites:
#   beets library available (linK: http://beets.io/)
#   Use two beets configurations and databases, one for mp3 with lyrics, one for flac without lyrics
#   config_mp3.yaml -> library_mp3.db
#   config_lossless.yaml -> library_lossless.db
#   WARNING CONVENTION: Rating playlists must be named x-stars.m3u, i.e 5-stars.m3u
#   WARNING LIMITATION: handle only mp3 for Lossy files and flac/m4a for lossless ones => easy to change
#   WARNING BEHAVIOUR:  The playlist name will be present as much as the number of occurences of the song in the playlist.
#                     This is a must in order not to have discrepencies with Beets' comments and this means the initial beets comments
#                     must be "clean" and reflect exactly files occurences in the playlist.
#                     Indeed, if the playlist appears only once in the comments whereas the song is present two times in the playlist:
#                     if we remove the second occurence from the playlist, the playlist will be removed from the comments with global substitution
#                     Note that it won't be the case if we remove the first occurence.
#   WARNING ISSUE: No space allowed in playlists! => because if [ ! -f $playlistFile ]; failed otherwise

# External dependencies:
    source ${BASH_SOURCE%/*}/../SETTINGS
    source ${BASH_SOURCE%/*}/utils.sh
#   updateFileComments.sh
#   getPairFile.sh
#   SQLite DB created according to createSQLiteDB.sql
#   comm command to do a diff between files
#   sed and sort commands
#   geopts for input parameters parsing
#
# Algo:
# For each file in the list
#   -> identify the quality of the file
#   -> get the corresponding pair (lossy->lossless or lossless->lossy)
#   -> update playlist in file comments and DB
#   -> update playlist in pair file comments
#   -> when playlist overwrite is activated, identify files removed from playlist,
#         and update the beet's comments and DB accordingly
#
# History
# Date            Version        Auteur        Commentaire
# 08/11/2016      1.0            Djhibee       Creation
# 23/11/2016      2.0            Djhibee       Merge with updateCommentsWithPlaylist script
# 11/03/2017      3.0            Djhibee       Take into account playlist songs' orders
#
####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################

####### Global variables #######
# File to use by default in case no param was given
FILE_PLAYLIST_DEFAULT="$VAR_DIRECTORY/toto.m3u"
# Store processed files in order not to re-process them
# in case of a stop before the full parsing of the playlist
PROCESSED_FILE_DEFAULT="$TMP_DIRECTORY/processedFiles.tmp"
# Comment update option chosen by default if not provided in input
UPDATE_OPERATION_DEFAULT=$ADD_OPTION
######## Shell variables ##########
debug_mode=${debug_mode:-0}
#######################
# END OF CONFIGURATION
#######################
#######################
## Other variables
#######################

### Globa variables ###
export ADD_OPTION="add"
export REMOVE_OPTION="remove"

### Constants ###
# Set to 1 to try to match by default by artist and title in last chance match
USE_LAST_CHANCE_MATCH_DEFAULT=0
# SQLITE DB update option chosen by default
UPDATE_DB_DEFAULT=0
# Playlist overwrite option chosen by default
OVERWRITE_PLAYLIST_DEFAULT=0
# Stores all processed files for whose no pair was found (except 1-star ranked songs)
PAIR_NOT_FOUND_LIST=""
# Stores all songs not found in beets library (no process possible so..)
MAIN_FILE_NOT_FOUND_LIST=""
# Gathers all files with 1-star ranking without a pair. Used because we dont care of missing pairs for 1-star ranked songs
MAIN_FILE_ONE_STAR_LIST=""
# In case of "LastChanceMatch", stores match pairs in order to review it later
LAST_CHANCE_MATCHES_TO_REVIEW=""

### Variables ###
# Stats to display after process
countPairFilesNotFound=0
countMainFilesNotFound=0
# index of song in playlist.
playlistOrder=0

##############################################
function usage {
  echo "USAGE: $0 [-hdlo] [-p playlistFile] [-u updateOperation] [-b processedFiles]

             -b processedFiles : Stores processed files in \$processedFiles in order not to re-process them in case of a stop before the full parsing of the playlist
             -d : store playlist in SQLITE DB
             -h --help : Display this message
             -l : try to match by artist and title in last chance match for pair songs
             -o : overwrite the playlist, namely remove former playlist from DB and replace it with the one provided
             -p playlistFile : playlist file to update
             -u updateOperation :
                      \"$ADD_OPTION\"  to add playlist in songs' Beets comments
                      \"$REMOVE_OPTION\" to remove  playlist from song's Beets comments
        "
  exit 0
}

function datacheck {
    [ ! -f $playlistFile ] && { endProg 200 ": $playlistFile is not a file." ; }
    [ "$updateOperation" = "$REMOVE_OPTION" ] && [ $overwritePlaylist -gt 0 ] && { endProg 300 ": Overwrite playlist option can only be used with \"$ADD_OPTION\" " ; }
    [ $updateOperation != "$REMOVE_OPTION" ] && [ $updateOperation != "$ADD_OPTION" ] && { endProg 900 ": Update operation can only be \"$ADD_OPTION\" or \"$REMOVE_OPTION\" " ; }
}

# Update processedFiles with the file in order not to re-process it
# in case of a stop before the full parsing of the playlist
function addProcessedSongToBackup {
  typeset fileToPrint="$1"
  if [ "$updateOperation" = $ADD_OPTION ]
  then
    echo "$fileToPrint" >> "$processedFiles"
  fi
}

# Set shell attributes and initialize output files
function initialize {
  if [[ $1 =~ ^--help ]]; then
    usage
  fi
  echo "...$0 script started..."
  if [ "$debug_mode" -eq 1 ]; then
    echo "debug mode is ON"
  else
    echo "debug mode is OFF"
  fi
  playlistFile=$FILE_PLAYLIST_DEFAULT
  updateOperation=$UPDATE_OPERATION_DEFAULT
  updateDB=$UPDATE_DB_DEFAULT
  useLastChanceMatch=$USE_LAST_CHANCE_MATCH_DEFAULT
  [ "$useLastChanceMatch" -gt 0 ] && { useLastChanceMatchOption="-l" ; } || useLastChanceMatchOption=""
  processedFiles=$PROCESSED_FILE_DEFAULT
  overwritePlaylist=$OVERWRITE_PLAYLIST_DEFAULT
  while getopts "hp:du:b:lo" option
  do
    case $option in
      b)
        processedFiles="$OPTARG";
        ;;
      d)
        updateDB=1
        ;;
      h)
        usage
        ;;
      l)
        useLastChanceMatch=1
        useLastChanceMatchOption="-l"
        ;;
      o)
        overwritePlaylist=1
        ;;
      p)
        playlistFile="$OPTARG";
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

  # Handle ../ in case the playlist path is absolute and not the current repo
  # ../foo/bar/playlist.m3u => playlist
  playlistName=$(basename "$playlistFile" ".m3u" | cut -f1 -d'.' )
  log "The playlist name is $playlistName"
  case "$playlistName" in
  *[543210]-stars*)
    echo "WARNING: overwritePlaylist option set to 0 since playlist $playlistName is a ranking one."
    overwritePlaylist=0
    ;;
  esac

  export PAIR_NOT_FOUND_LIST="$PLAYLIST_DIRECTORY_TO_BACKUP/$playlistName.pairsNotFound.txt"
  export MAIN_FILE_NOT_FOUND_LIST="$PLAYLIST_DIRECTORY_TO_BACKUP/$playlistName.NotFoundInBeets.txt"
  export MAIN_FILE_ONE_STAR_LIST="$PLAYLIST_DIRECTORY_TO_BACKUP/$playlistName.noPairAndOneStar.txt"
  export LAST_CHANCE_MATCHES_TO_REVIEW="$PLAYLIST_DIRECTORY_TO_BACKUP/$playlistName.matchesToReview.txt"

  log "Processed music list is: $playlistFile"
  log "Music files with no pair dumped in $PAIR_NOT_FOUND_LIST"
  log "Use last chance match option is set to $useLastChanceMatch"
  log "Chosen update operation is $updateOperation"
  log "Update DB option is set to $updateDB"
  log "Backup file is $processedFiles"
  log "Overwrite playlist option is set to $overwritePlaylist"
  timestamp="$(date +'%Y%m%d%H%M')"
  echo "###################################" >> $PAIR_NOT_FOUND_LIST
  echo "###################################" >> $MAIN_FILE_NOT_FOUND_LIST
  echo "###################################" >> $MAIN_FILE_ONE_STAR_LIST
  echo "###################################" >> $LAST_CHANCE_MATCHES_TO_REVIEW
  echo "Run starts: $timestamp" >> $PAIR_NOT_FOUND_LIST
  echo "Run starts: $timestamp" >> $MAIN_FILE_NOT_FOUND_LIST
  echo "Run starts: $timestamp" >> $MAIN_FILE_ONE_STAR_LIST
  echo "Run starts: $timestamp" >> $LAST_CHANCE_MATCHES_TO_REVIEW
  echo "###################################" >> $PAIR_NOT_FOUND_LIST
  echo "###################################" >> $MAIN_FILE_NOT_FOUND_LIST
  echo "###################################" >> $MAIN_FILE_ONE_STAR_LIST
  echo "###################################" >> $LAST_CHANCE_MATCHES_TO_REVIEW

  ########################################################################################
  # Remove old files from playlist in DB and comments when playlist overwrite is activated
  ########################################################################################
  if [[ "$overwritePlaylist" -gt 0 ]]
  then
    echo "Removing old playlist $playlistName"
    # Remove from lossy and lossless comments:
    beet  -c $CONFIG_LOSSY list -p comments:"$playlistName" | sort -fb | tr -d '\r' > "$TMP_DIRECTORY/old$playlistName.tmp"
    beet  -c $CONFIG_LOSSLESS list -p  comments:"$playlistName" | sort -fb | tr -d '\r' >> "$TMP_DIRECTORY/old$playlistName.tmp"
    while read file; do
      fileProper="$file"
      if [ -n "$fileProper" ] && [ "$fileProper" != "" ] && [ "$fileProper" ]
      then
        $UPDATE_FILE_COMMENTS_SCRIPT_PATH -c -s "$fileProper" -p "$playlistName" -u "$REMOVE_OPTION" -r "-1" | sed 's/^/     /'
      fi
    done < "$TMP_DIRECTORY/old$playlistName.tmp"

    # Remove from DB
    deleteDBRequest="DELETE
                     FROM PLAYLISTS
                     WHERE PLAYLISTNAME =\"$playlistName\"
                     ;"
    sqlite3 $SQLITEDB <<< "$deleteDBRequest"
    log "Old playlist is removed from DB " $NO_COLOR
  fi
}

function cleanFiles {
  # Replace \r by \r\n (if file created on OSX) and create a copy of the playlist to work on it
  sed 's/\r$/\r\n/g' "$playlistFile" > "$playlistFile.tmp2"
  # Replace \ by \\ for string regex
  sed 's/\\/\\\\/g' "$playlistFile.tmp2" > "$playlistFile.tmp"
  rm -f "$playlistFile.tmp2"
}

initialize "$@"
datacheck
cleanFiles

echo "... Start $playlistFile processing"
while read file; do
  typeset fileProper="$file"
  [ $overwritePlaylist -gt 0 ] && { playlistOrder=$((playlistOrder + 1)) ; }
  # uncomment when running on Macosx
  #fileProper="`iconv -f utf-8 -t utf-8-mac <<< "$file"`"
  log "Processing $fileProper"
  # Parse only lines that contain .mp3 or .flac/m4a files and not #recycle and @eadir
  if echo "$fileProper" | grep -i 'mp3\|flac\|m4a' | grep -i -v '#recycle\|@eaDir' > /dev/null ; then

    ##############################
    # Get corresponding pair file
    ###############################
    getPairFile_result=""
    $GET_PAIR_FILE_SCRIPT_PATH -d $useLastChanceMatchOption -s "$fileProper" -o getPairFile_result | sed 's/^/     /'
    pairFilePath=`cat getPairFile_result`
    # Handle main file not found error
    [ $? -eq 100 ] && {  countMainFilesNotFound=$((countMainFilesNotFound + 1)) ; }
    # Update stats and debug logs
    if [[ -n "$pairFilePath" ]]
    then
      log "$pairFilePath was found as pair"
    else
      # pair song was not found
      log "No pair was found for $fileProper "
      countPairFilesNotFound=$((countPairFilesNotFound + 1))
    fi
    addProcessedSongToBackup "$fileProper"

    ##################################
    # Update Playlist in files and DB
    ##################################
    if [[ "$overwritePlaylist" -gt 0 ]]
    then
      # in case of overwrite, update Operation is "ADD"
      # Other solution: source script in a subshell ( thanks to () ) in order not to corrupt passed variables
      # source let us call a script even if it is not executable! But here it was so...
      # (. ./06_updateFileComments.sh songPath playlistName updateOperation updateDB songPlayListOrder )
      echo "Overwriting comments and db for main file $fileProper"
      $UPDATE_FILE_COMMENTS_SCRIPT_PATH -c -d -s "$fileProper" -p "$playlistName" -u "$updateOperation" -r "$playlistOrder" | sed 's/^/     /'

      # we also update the comments of the pair file in beets but not in the DB!
      # in case of remove, only one instance will be removed from beets' comments
      [[ -n "$pairFilePath" ]] && {
        echo "Overwriting comments only for pair file $pairFilePath"
        $UPDATE_FILE_COMMENTS_SCRIPT_PATH -c -s "$pairFilePath" -p "$playlistName" -u "$updateOperation" -r "$playlistOrder" | sed 's/^/     /'
      }
    elif [ "$updateOperation" = "$ADD_OPTION" ]
    then
      # for add Option, we want to add the song at the end of the playlist
      echo "Add main file $fileProper at the end of the playlist"
      $UPDATE_FILE_COMMENTS_SCRIPT_PATH -c -d -s "$fileProper" -p "$playlistName" -u "$ADD_OPTION" -r 0 | sed 's/^/     /'
      [[ -n "$pairFilePath" ]] && {
        echo "Add pair file $pairFilePath at the end of the playlist"
        $UPDATE_FILE_COMMENTS_SCRIPT_PATH -c -s "$pairFilePath" -p "$playlistName" -u "$ADD_OPTION" -r 0 | sed 's/^/     /'
      }
    else
      ## Remove is the last possibility
      # for remove option, we want to remove only the last occurence of the song
      echo "Remove main file $fileProper from the end of the playlist"
      $UPDATE_FILE_COMMENTS_SCRIPT_PATH -c -d -s "$fileProper" -p "$playlistName" -u "$REMOVE_OPTION" -r 0 | sed 's/^/     /'
      [[ -n "$pairFilePath" ]] && {
        echo "Remove pair file $pairFilePath from the end of the playlist"
        $UPDATE_FILE_COMMENTS_SCRIPT_PATH -c -s "$pairFilePath" -p "$playlistName" -u "$REMOVE_OPTION" -r 0 | sed 's/^/     /'
      }
    fi
  fi # check mp3 /flac
done < "$playlistFile.tmp"


###########################################################
#Terminate program by providing stats and cleaning of files
###########################################################

echo "number of pair files not found from playlist: $countPairFilesNotFound"
echo "number of files not found from beets: $countMainFilesNotFound"

# Clean files
if [ "$debug_mode" -eq 0 ]; then
  rm -f "$TMP_DIRECTORY/$file_pairFilePath.tmp"
  rm -f "$playlistFile.tmp"
  rm -f "$TMP_DIRECTORY/old$playlistName.tmp"
fi

endProg 0
