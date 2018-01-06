#!/bin/bash
# May be easily converted to sh compatible script if needed, since a very few bashisms are used ([[]]...)
#
# Synopsis :
#       Lowest level script.
#       Return the corresponding pair file from a song (using SQLITe DB or using Beets' attributes)
#       Insert also the tuple (lossy, lossless) in SQLite DB FILES table (optional) to improve performances
#       for next searches.
#
# Usage: Run command ./getPairFile.sh --help
#
# Return codes:
#             0: Everything went fine
#             1: Wrong usage of the command
#             100: Music file $mainFile was not found in Beets DB
#             200: $playListPath is not a file
#
# Pre-requisites:
#
# External dependencies:
    source ${BASH_SOURCE%/*}/utils.sh
#   SQLite DB created according to createSQLiteDB.sql
#   geopts for input parameters parsing
#
# Algo:
#   -> identify the quality of the file
#   -> get the corresponding pair (lossy->lossless or lossless->lossy)
#     -> fetch  beets attributes
#           beet  -c $CONFIG list -f '$artist$}$album$}$title$}$mb_trackid' path:"$fileProper"
#     -> if useLastChanceMatch=1 then try to match by artist and title in last chance match
#   -> add couple to the database if not present
#       (TODO For last chance matches, avoid to match a live version with a studio version)
#   -> add as orphan otherwise
#
# History
# Date            Version        Auteur        Commentaire
# 13/03/2017      1.0            Djhibee       Creation

####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################
# Stores all processed files for whose no pair was found (except 1-star ranked songs)
PAIR_NOT_FOUND_LIST=${PAIR_NOT_FOUND_LIST:-"$VAR_DIRECTORY/pairNotFoundList.txt"}
# Gathers all files with 1-star ranking without a pair. Used because we dont care of missing pairs for 1-star ranked songs
MAIN_FILE_ONE_STAR_LIST=${MAIN_FILE_ONE_STAR_LIST:-"$VAR_DIRECTORY/mainFileOneStarList.txt"}
# In case of "LastChanceMatch", stores match pairs in order to review it later
LAST_CHANCE_MATCHES_TO_REVIEW=${LAST_CHANCE_MATCHES_TO_REVIEW:-"$VAR_DIRECTORY/lastChanceMatchesToReview.txt"}
# Stores all songs not found in beets library (no process possible so..)
MAIN_FILE_NOT_FOUND_LIST=${MAIN_FILE_NOT_FOUND_LIST:-"$VAR_DIRECTORY/mainFileNotFoundList.txt"}
debug_mode=${debug_mode:-1}
#######################
# END OF CONFIGURATION
#######################
#########################
## Other variables
#########################

usage="USAGE: $0 [-hdl] -s songPath [-o outputFile]

           -d : use SQLITE DB to store and retrieve pairs (improve perfs)
           -h --help : Display this message
           -l : try to match by artist and title in last chance match for pair songs
           -o : file where to store the found pair file path
           -s : original song file

      "

function usage {
  echo "$usage"
  exit 0
}

function datacheck {
    if [[ ! -f "$mainFile" ]]
    then
       # TODO : uncomment once file are ready
       #endProg 200 ": $mainFile is not a file."
       echo ""
    fi

}

# Print file for which no pair was found in $PAIR_NOT_FOUND_LIST file or $MAIN_FILE_ONE_STAR_LIST file
function printPairNotFound {
  typeset musicFileWithNoPair="$1"
  typeset fileComments="$2"
  if echo "$fileComments" | grep -i '1-stars' > /dev/null ; then
    log "NOT FOUND pair music file for 1-star ranked: $musicFileWithNoPair" $RED_COLOR
    echo "$musicFileWithNoPair" >> "$MAIN_FILE_ONE_STAR_LIST"
  else
    log "NOT FOUND pair music file for: $musicFileWithNoPair" $RED_COLOR
    echo "$musicFileWithNoPair" >> "$PAIR_NOT_FOUND_LIST"
  fi
}

# Set global attributes and log few pieces of info
function initialize {
  if [ "$debug_mode" -eq 1 ]; then
    echo "debug mode is ON"
  else
    echo "debug mode is OFF"
  fi
  if [[ $1 =~ ^--help ]]; then
    usage
  fi
  echo "$0 script started..."
  if [ "$debug_mode" -eq 1 ]; then
    echo "debug mode is ON"
  else
    echo "debug mode is OFF"
  fi
  updateDB=0
  useLastChanceMatch=0
  matchType=0
  tupleAlreadyInDB=0
  __dummy=""
  __resultvar="__dummy"
  while getopts "hdls:o:" option
  do
    case $option in
      d)
        updateDB=1
        ;;
      h)
        usage
        ;;
      l)
        useLastChanceMatch=1
        ;;
      o)
        __resultvar="$OPTARG"
        ;;
      s)
        mainFile="$OPTARG";
        # important to trim files from \r and \n !
        mainFile=$(echo $mainFile| tr -d '\n' | tr -d '\r' )
        ;;
      :)
        endProg 1 "Option $OPTARG needs an argument" ;
        ;;
      \?)
        endProg 1 "$OPTARG : invalid option" ;
        ;;
    esac
  done

  ### identify the file music quality###
  mainFileQuality="LOSSY"
  pairFileQuality="LOSSLESS"
  configMainFile=$CONFIG_LOSSY
  configPairFile=$CONFIG_LOSSLESS
  if echo "$mainFile" | grep -i 'flac\|m4a' > /dev/null ; then
    mainFileQuality="LOSSLESS"
    pairFileQuality="LOSSY"
    configMainFile=$CONFIG_LOSSLESS
    configPairFile=$CONFIG_LOSSY
  fi
  log "quality of main file: $mainFileQuality"
}

function getPairFile {

  # check first if pair file already present in SQL DB when DB option activated
  # the priority is given to the perfect match of course
  if [ "$updateDB" -eq 1 ]
  then
    #TODO : AND $pairFileQuality != ''
    log "Try to find pair file in DB..."
    selectDBRequest="SELECT $pairFileQuality
                     FROM FILES
                     WHERE $mainFileQuality=\"$mainFile\"
                     ORDER BY MATCH_TYPE ASC LIMIT 1
                     ;
                    "
    pairFilePath=`sqlite3 $SQLITEDB <<< "$selectDBRequest"`
  fi

  if [[ -z "$pairFilePath" ]] && [ "$only_use_db_for_pairs" -lt 1 ]
  then
    log "Try to find pairFile from Beets..."
    # pair file not present, we will guess it from mainfile's beets attributes
    tupleAlreadyInDB=0
    matchType=0

    # get main file data from beet library
    # } must be escaped with $ (see beet doc)
    data=$(beet  -c $configMainFile list -f '$artist$}$album$}$title$}$mb_trackid$}$mb_albumid$}$comments' path:"$mainFile")
    log "data: $data"
    if [[ -n "$data" ]]
    then # mainFile was found in beet DB

      #startIndex=$((startIndex + 1))
      # we set } as separator to split data per category
      IFS='}' read -r -a array <<< "$data"
      if [ -n "${array[3]}" ] && [ "${array[3]}" != "" ] && [ "${array[3]}" ]
      then
        # First we look for the pair song via its musicbrainz id and its album
        # We don't care if mb_albumid is null since we dont use regex
        # May return several results only in that case:
        # album = thriller without mb_albumid -> matches also album thriller 25
        log "looking for musicbrainzid ${array[3]} album ${array[1]} mb_albumid ${array[4]}"
        pairFilePath=$(beet  -c $configPairFile list -p mb_trackid:"${array[3]}" mb_albumid:"${array[4]}" album:"${array[1]}" )
        if [[ -z "$pairFilePath" ]]
        then
          log "looking for musicbrainzid ${array[3]} album ${array[1]}"
          pairFilePath=$(beet  -c $configPairFile list -p mb_trackid:"${array[3]}" album:"${array[1]}" )
        fi
      fi
      if [[ -z "$pairFilePath" ]]
      then
        # pair song was not found, we try again using  album, artist and title
        if [ -n "${array[2]}" ] && [ "${array[2]}" != "" ] && [ "${array[2]}" ]
        # we need a title otherwise it's impossible to find it
        then
          log "looking for artist:${array[0]} album:${array[1]} title:${array[2]}"
          pairFilePath=$(beet  -c $configPairFile list -p  album:"${array[1]}" artist:"${array[0]}" title:"${array[2]}" mb_albumid:"${array[4]}" )

          if [[ -z "$pairFilePath" ]]
          then
            pairFilePath=$(beet  -c $configPairFile list -p  album:"${array[1]}" artist:"${array[0]}" title:"${array[2]}" )
          fi
        fi
      fi
      if [[ -z "$pairFilePath" ]] && [ $useLastChanceMatch -eq "1" ]
      then
        # pair song was not found, we try again using only  artist and title provided we activated the option "lastChanceMatch"
        # We put it in a file because the result could return several paths
        log "looking for artist:${array[0]} title:${array[2]}"
        # MAY USE REGEX for title if needed with "::" instruction
        beet  -c $configPairFile list -p  artist:"${array[0]}" "title:${array[2]}" > "$TMP_DIRECTORY/file_pairFilePath.tmp"
        if [[ -s "$TMP_DIRECTORY/file_pairFilePath.tmp" ]]
        then
          if [[ $mainFileQuality = "LOSSY" ]]
          then
            matchType=1
          else
            matchType=2
          fi
          # in order to double check that the correct pair was matched, we put the result in a dedicated file to review it later
          echo "###################" >> "$LAST_CHANCE_MATCHES_TO_REVIEW"
          echo "file to match: $mainFile" >> "$LAST_CHANCE_MATCHES_TO_REVIEW"
          echo "potential matches (last would be the one selected):" >> "$LAST_CHANCE_MATCHES_TO_REVIEW"
          while read potentialMatches; do
            echo "$potentialMatches" >> "$LAST_CHANCE_MATCHES_TO_REVIEW"
            pairFilePath="$potentialMatches"
          done < "$TMP_DIRECTORY/file_pairFilePath.tmp"
        fi
      fi

    else # data = null, music file not found in beet db
      echo "$mainFile" >> "$MAIN_FILE_NOT_FOUND_LIST"
      endProg 100 "Music file $mainFile was not found in Beets DB"
    fi # mainFile in beets?
  else
    tupleAlreadyInDB=1
    log "Pair File found in DB or search by tags disabled"
  fi # pair already present in sql db?

}

# Add file(s) in SQLite FILES table in order to retrieve the pair faster later
function addFilesInDB {

  if [ "$updateDB" -eq 1 ] && [ $tupleAlreadyInDB -eq 0 ]
  then
    if [[ -n "$pairFilePath" ]]
    then
      # pair song was found : insert tuple in sqlite database
      # check if pair file already present in DB as orphan in order not to create fake orphans
      # by construction, only one ID can result
      # important to trim files from \r and \n !!!!!
      pairFilePath=$(echo $pairFilePath| tr -d '\n' | tr -d '\r' )
      checkPairDBRequest="SELECT ID
                          FROM FILES
                          WHERE $pairFileQuality=\"$pairFilePath\"
                          AND $mainFileQuality=\"\"
                          ;"
      isPairOrphanPresent=`sqlite3 $SQLITEDB <<< "$checkPairDBRequest"`
      if [[ -n "$isPairOrphanPresent" ]]
      then # Pair Orphan is reused instead of creating another line
        log "Pair File $pairFilePath already present in DB but orphan: entry with ID $isPairOrphanPresent is reused"
        echo "$isPairOrphanPresent|$mainFile|$pairFilePath|$matchType"
        #startIndex=$((startIndex - 1))
        dbRequest="UPDATE FILES
                   SET $mainFileQuality = \"$mainFile\" ,
                   MATCH_TYPE=$matchType
                   WHERE ID = $isPairOrphanPresent
                   ;"
        sqlite3 $SQLITEDB <<< "$dbRequest"
        # Potential other orphan is removed
        checkMainDBRequest="SELECT ID
                            FROM FILES
                            WHERE $mainFileQuality=\"$mainFile\"
                            AND $pairFileQuality=\"\"
                            ;"
        isMainOrphanPresent=`sqlite3 $SQLITEDB <<< "$checkMainDBRequest"`
        if [[ -n "$isMainOrphanPresent" ]]
        then
          deleteDBRequest="DELETE
                           FROM FILES
                           WHERE ID =\"$isMainOrphanPresent\"
                           ;"
          sqlite3 $SQLITEDB <<< "$deleteDBRequest"
        fi
      else # No pair orphan exists, we check for a main orphan
        checkMainDBRequest="SELECT ID
                            FROM FILES
                            WHERE $mainFileQuality=\"$mainFile\"
                            AND $pairFileQuality=\"\"
                            ;"
        isMainOrphanPresent=`sqlite3 $SQLITEDB <<< "$checkMainDBRequest"`
        if [[ -n "$isMainOrphanPresent" ]]
        then
          # Main Orphan is reused instead of creating another line
          log "Main File $mainFile already present in DB but orphan: entry with ID $isMainOrphanPresent is reused"
          echo "$isMainOrphanPresent|$mainFile|$pairFilePath|$matchType"
          #startIndex=$((startIndex - 1))
          dbRequest="UPDATE FILES
                     SET $pairFileQuality = \"$pairFilePath\" ,
                     MATCH_TYPE=$matchType
                     WHERE ID = \"$isMainOrphanPresent\"
                     ;"
          sqlite3 $SQLITEDB <<< "$dbRequest"
        else
          # neither main nor pair was present in DB

          if [[ $matchType -eq 0 ]]
          then
            log "Clean DB before inserting perfect match"
            cleanLastChanceMatchesFromDB "$pairFilePath"
          fi

          log "Insert brand new tuple"
          echo "newID|$mainFile|$pairFilePath|$matchType"
          dbRequest="INSERT
                     INTO FILES ($mainFileQuality,$pairFileQuality, MATCH_TYPE)
                     VALUES (\"$mainFile\", \"$pairFilePath\", $matchType )
                     ;"
          sqlite3 $SQLITEDB <<< "$dbRequest"
        fi
      fi
    else
      # pair song was not found at all, we insert main orphan if not already present
      if [[ $mainFileQuality = "LOSSY" ]]
      then
        matchType=-1
      else
        matchType=-2
      fi
      checkMainDBRequest="SELECT ID
                          FROM FILES
                          WHERE $mainFileQuality=\"$mainFile\"
                          ;"
      isMainOrphanPresent=`sqlite3 $SQLITEDB <<< "$checkMainDBRequest"`
      if [[ -z "$isMainOrphanPresent" ]]
      then
        orphanDbRequest="INSERT
                         INTO FILES ($mainFileQuality,$pairFileQuality, MATCH_TYPE)
                         VALUES ( \"$mainFile\", \"\" , $matchType)
                         ;"
        sqlite3 $SQLITEDB <<< "$orphanDbRequest"
      fi
    fi
  fi
}

# Handle that case:
#      A  <-  A1'  : last chance (match type = 1 or 2)
#      A  <-  A2'  : last chance (match type = 1 of 2)
#      A  <-  A'   : full match  (match type = 0 )
#      A1 ->  A1' () : full match + A1' as another entry (A <- A1') ans A as a full match recorded (A')
#                                     Thus we delete entry (A <- A1')
# By construction, an orphan cannot exist if match (perfect or partial) exists
function cleanLastChanceMatchesFromDB {
  # we use a correlated subquery
  getIDToCleanDBRequest="SELECT ID
                        FROM FILES AS a
                        WHERE $pairFileQuality=\"$1\"
                        AND $mainFileQuality IN
                          ( SELECT $mainFileQuality
                            FROM FILES AS b
                            WHERE b.ID != a.ID
                            AND b.$mainFileQuality=a.$mainFileQuality
                            AND MATCH_TYPE = 0
                          )
                        ;"
  idToDelete=`sqlite3 $SQLITEDB <<< "$getIDToCleanDBRequest"`

  if [[ -n "$idToDelete" ]]
  then
    echo "Delete line $idToDelete because of perfect match for $mainFile and $pairFilePath "
    deleteDBRequest="DELETE
                     FROM FILES
                     WHERE ID =\"$idToDelete\"
                     ;"
    sqlite3 $SQLITEDB <<< "$deleteDBRequest"
  fi

}


# "" are mandatory otherwise parameters will be split by space
initialize "$@"
datacheck
getPairFile
if [[ -z "$pairFilePath" ]]; then
  log "Pair not found for file $mainFile"
  printPairNotFound "$mainFile" "${array[5]}"
else
  log "     $mainFile   -> $pairFilePath "
fi

addFilesInDB

# Return the pair file path in the provided file in order to be treated by the caller
#printf -v "$__resultvar" '%s' "$pairFilePath"
echo "$pairFilePath" > $__resultvar

endProg 0
