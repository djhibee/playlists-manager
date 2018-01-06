#!/bin/bash
# SetPairsInSQLDBSQLDB.sh
#
# Synopsis:
#           Low level script
#           Manually set the pair files in DB from songs using a csv file
#
# Usage: Run ./setPairsInSQLDB.sh --help
#
# Return codes:
#             0: Everything went fine
#             1: Wrong usage of the command
#             200: $csvFile is not a file
#
# External dependencies:
    source ${BASH_SOURCE%/*}/../SETTINGS
    source ${BASH_SOURCE%/*}/utils.sh
#   SQLite DB created according to createSQLiteDB.sql
#   geopts for input parameters parsing
#
# Algo: For each song in the list:
#            -> insert provided tuple
#                -> check for 2nd column orphan first (pair file)
#                -> check for 1st column orphan if first check did not succeed (main file)
#                -> insert new line otherwise
#
# WARNING LIMITATION: All the songs in a column must have the same quality, namely either all lossy, or all lossless
#
# Input:
#        CSV file with 3 columns separeted by a ';'. First one is the main file, second one is its pair file,
#        third one is the type of match (0->perfectMatch, 1 -> getLosslessFromLossy, 2 ->getLossyFromLossless
#        -1 => lossy orphan,  -2 => lossless orphan)
#        example: toto.csv
#            song1.mp3;song1.flac;0
#            song2.mp3;song2.flac;0
#            song3.mp3;song5.flac;2
#
# History
# Date            Version        Auteur        Commentaire
# 20/03/2017      1.0            Djhibee       Creation
# 10/07/2017      2.0            Djhibee       New column for last chances

####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################
debug_mode=${debug_mode:-0}
# Used to restore IFS at the end of the process in case we source the script
OLDIFS=$IFS
# Character used to separate columns in the csv file
IFS=";"
# Quality for songs in the first column of the csv file. Value can be either "LOSSY" or "LOSSLESS"
C1_QUALITY="LOSSY"
OVERRIDE_EXISTING_TUPLE_DEFAULT=0
#######################
# END OF CONFIGURATION
#######################
#################################
## Other constants and variables
#################################

### Constants ###
# Song quality for paths in the second column of the csv file
C2_QUALITY=""
[ "$C1_QUALITY" = "LOSSY" ] && { C2_QUALITY="LOSSLESS" ; } || { C2_QUALITY="LOSSY" ; }

## Variables ###
# Stats to display after process

function usage {
  echo "USAGE: $0  [-f songsFile] [-ho]
             -f: csv file containing songs' paths to insert in DB
             -h --help : Display this message
             -o: overwrite existing tuples

        "
  exit 0
}

function datacheck {
  [[ ! -f $songsFile ]] && { endProg 200 ": $songsFile is not a file." ; }
}

function cleanFiles {
  # Replace \r by \r\n (if file created on OSX) and create a copy of the playlist to work on it
  #set -x
  sed 's/\r$/\r\n/g' "$songsFile" > "$TMP_DIRECTORY/$songsFile.tmp"
  # Replace \ by \\ for string regex
  sed 's/\\/\\\\/g' "$TMP_DIRECTORY/$songsFile.tmp" > "$TMP_DIRECTORY/$songsFile.cleaned"
  #set +x
  rm -f "$TMP_DIRECTORY/$songsFile.tmp"
}

# Handle that case:
#      A  <-  A1'  : last chance
#      A  <-  A2'  : last chance
#      A  <-  A'   : full match
#      A1 ->  A1' () : full match + A1' as another entry (A <- A1') ans A as a full match recorded (A')
#                                     Thus we delete entry (A <- A1')
function cleanLastChanceMatchesFromDB {
  # we use a correlated subquery
  getIDToCleanDBRequest="SELECT ID
                  FROM FILES AS a
                  WHERE $C2_QUALITY=\"$1\"
                  AND $C1_QUALITY IN
                    ( SELECT $C1_QUALITY
                      FROM FILES AS b
                      WHERE b.ID != a.ID
                      AND b.$C1_QUALITY=a.$C1_QUALITY
                      AND MATCH_TYPE = 0
                    )
                  ;"

  #set -x
  idToDelete=`sqlite3 $SQLITEDB <<< "$getIDToCleanDBRequest"`
  #set +x

  if [[ -n "$idToDelete" ]]
  then
    #set -x
    deleteDBRequest="DELETE
                     FROM FILES
                     WHERE ID =\"$idToDelete\"
                     ;"
    sqlite3 $SQLITEDB <<< "$deleteDBRequest"
    #set +x
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
  songsFile="dummySongFile"
  overwriteExistingTuples=$OVERRIDE_EXISTING_TUPLE_DEFAULT
  while getopts "f:hlo" option
  do
    case $option in
      h)
        usage
        ;;
      f)
        songsFile="$OPTARG";
        ;;
      o)
        overwriteExistingTuples=1
        log "overwriteExistingTuples option is activated"
        ;;
      :)
        endProg 1 "Option $OPTARG needs an argument" ;
        ;;
      \?)
        endProg 1 "$OPTARG : invalid option" ;
        ;;
    esac
  done

  echo "Inserting songs from $songsFile in SQLITE DB..."
}

######### Main ##########

initialize "$@"
datacheck
cleanFiles

echo "Column 1 of file: $C1_QUALITY"
echo "Column 2 of file: $C2_QUALITY"
echo "Column 3 is type of match"

while read mainFile pairFile matchType
do
    log "Main File is : $mainFile"
    log "Pair file is : $pairFile"
    log "Type of match: $matchType"
    #log "length(pairFile)==$(echo -ne "${pairFile}" | wc -m)"
    # important to trim files from \r and \n !!!!!
    mainFile=$(echo $mainFile| tr -d '\n' | tr -d '\r' )
    pairFile=$(echo $pairFile| tr -d '\n' | tr -d '\r' )
    matchType=$(echo $matchType| tr -d '\n' | tr -d '\r' )
    #log "pairFile_trimmed='${pairFile}'"
    #log "length(pairFile_trimmed)==$(echo -ne "${pairFile}" | wc -m)"

    # check if pair file already present in DB as orphan in order not to create fake orphans
    # by construction, only one ID can result
    checkPairDBRequest="SELECT ID
                        FROM FILES
                        WHERE $C2_QUALITY=\"$pairFile\"
                        AND $C1_QUALITY=\"\"
                        ;"
    isPairOrphanPresent=`sqlite3 $SQLITEDB <<< "$checkPairDBRequest"`
    if [[ -n "$isPairOrphanPresent" ]]
    then # Pair Orphan is reused instead of creating another line
      log "Pair File $pairFile already present in DB but orphan: entry with ID $isPairOrphanPresent is reused"
      #startIndex=$((startIndex - 1))
      dbRequest="UPDATE FILES
                 SET $C1_QUALITY = \"$mainFile\" ,
                 MATCH_TYPE=$matchType
                 WHERE ID = $isPairOrphanPresent
                 ;"
      sqlite3 $SQLITEDB <<< "$dbRequest"
      continue;
    else # No pair orphan exists, we check for a main orphan
      checkMainDBRequest="SELECT ID
                          FROM FILES
                          WHERE $C1_QUALITY=\"$mainFile\"
                          AND $C2_QUALITY=\"\"
                          ;"

      isMainOrphanPresent=`sqlite3 $SQLITEDB <<< "$checkMainDBRequest"`
      if [[ -n "$isMainOrphanPresent" ]]
      then
        # Main Orphan is reused instead of creating another line
        log "Main File $mainFile already present in DB but orphan: entry with ID $isMainOrphanPresent is reused"
        #startIndex=$((startIndex - 1))
        dbRequest="UPDATE FILES
                   SET $C2_QUALITY = \"$pairFile\" ,
                   MATCH_TYPE=$matchType
                   WHERE ID = $isMainOrphanPresent
                   ;"
        sqlite3 $SQLITEDB <<< "$dbRequest"
        continue;
      else
        if [[ $overwriteExistingTuples -eq 1 ]]
        then
          # we replace a potential existing tuple whose file is mainFile
          checkTupleDBRequest="SELECT ID
                               FROM FILES
                               WHERE $C1_QUALITY=\"$mainFile\"
                               AND $C2_QUALITY != \"\"
                               AND MATCH_TYPE=0
                               ;"
          isTuplePresent=`sqlite3 $SQLITEDB <<< "$checkTupleDBRequest"`
          if [[ -n "$isTuplePresent" ]]
          then
            # tuple is reused instead of creating another line
            #log "Tuple (\"$mainFile\":\"$pairFile\") already present in DB, entry \"$isTuplePresent\" is reused"
            #startIndex=$((startIndex - 1))
            #set -x
            dbRequest="UPDATE FILES
                       SET $C1_QUALITY=\"$mainFile\" ,
                           $C2_QUALITY=\"$pairFile\" ,
                           MATCH_TYPE=$matchType
                       WHERE ID = \"$isTuplePresent\"
                       ;"
            sqlite3 $SQLITEDB <<< "$dbRequest"
            continue;
            #set +x
          fi
        fi

        # neither main nor pair was present in DB

        if [[ $matchType -eq 0 ]]
        then
          log "Clean DB before inserting perfect match"
          cleanLastChanceMatchesFromDB "$pairFile"
        fi

        log "Insert brand new tuple"
        dbRequest="INSERT
                   INTO FILES ($C1_QUALITY,$C2_QUALITY,MATCH_TYPE)
                   VALUES (\"$mainFile\", \"$pairFile\", $matchType )
                   ;"
        sqlite3 $SQLITEDB <<< "$dbRequest"

      fi
    fi

done < "$TMP_DIRECTORY/$songsFile.cleaned"

if [ "$debug_mode" -eq 0 ]; then
  rm -f "$TMP_DIRECTORY/$songsFile.cleaned"
fi

IFS=$OLDIFS

endProg 0
