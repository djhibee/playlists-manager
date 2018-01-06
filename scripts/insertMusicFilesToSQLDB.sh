#!/bin/bash

# Synopsis :
#   Medium level script.
#   Insert files in a SQLite DB to improve performances of a pair song find.
# WARNING LIMITATION: handle only mp3 for Lossy files and flac/m4a for lossless ones => easy to change
#
# Pre-requisites:
#   beets library available (linK: http://beets.io/)
#   Use two configurations and db, one for mp3 with lyrics, one for flac without lyrics
#   config_mp3.yaml -> library_mp3.db
#   config_lossless.yaml -> library_lossless.db
#
# External dependencies:
    source ${BASH_SOURCE%/*}/utils.sh
#   getPairFile.sh
#
# Algo:
#   For each file in the list
#     -> getPairFile
#
# Usage: Run ./insertMusicFilesToSQLDB --help
#
# to prepare input files (optional):
# sort -uf music-mp3.txt | tr -d '\r' > music-mp3.txt.sorted
# sed '/@eaDir/d' music-mp3.txt.sorted > music-mp3.txt.sorted.filtered
# sed '/#recycle/d' music-mp3.txt.sorted.filtered > music-mp3.txt.sorted.filtered2
# sed 's/\\/\//g' music-mp3.txt.sorted.filtered2 > music-mp3.txt.clean
# sort -u mp3PairedWithFlac.txt | tr -d '\r' > mp3PairedWithFlac.txt.clean
# comm -2 -3 music-mp3.txt.sorted.filtered2 mp3PairedWithFlac.txt > mp3NotPairedToFlac.txt
# comm -3 music-mp3.txt.sorted.filtered2 mp3PairedWithFlac.txt > mp3NotPairedToFlac.txt.v2
# comm -1 -3 music-mp3.txt.clean mp3PairedWithFlac.txt > mp3NotPairedToFlac.txt.v3
#
# History
# Date            Version        Auteur        Commentaire
# 08/11/2016      1.0            Djhibee       Creation
# 19/03/2017      2.0            Djhibee       Full refactoring

####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################
debug_mode=${debug_mode:-1}

#######################
# END OF CONFIGURATION
#######################

#################################
## Other constants and variables
#################################

### Constants ###
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
export countPairFilesNotFound=0
export countMainFilesNotFound=0

function usage {
  echo "USAGE: $0  -f songsFile [-lh]
             -f: file containing songs' paths to insert in DB
             -h --help : Display this message
             -l: try to match by artist and title in last chance match for pair songs


        "
  exit 0
}

function datacheck {
  [[ ! -f $songsFile ]] && { endProg 200 ": $songsFile is not a file." ; }
}

# Set shell attributes and initialize output files
function initialize {
  if [[ $1 =~ ^--help ]]; then
    usage
  fi
  echo "insertMusicFilesToSQLDB script started..."
  if [ "$debug_mode" -eq 1 ]; then
    echo "debug mode is ON"
  else
    echo "debug mode is OFF"
  fi
  songsFile="0"
  useLastChanceMatch=0
  while getopts "f:hlo" option
  do
    case $option in
      h)
        usage
        ;;
      f)
        songsFile="$OPTARG";
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

  export PAIR_NOT_FOUND_LIST="$songsFile.pairsNotFound.txt"
  export MAIN_FILE_NOT_FOUND_LIST="$songsFile.NotFoundInBeets.txt"
  export MAIN_FILE_ONE_STAR_LIST="$songsFile.noPairAndOneStar.txt"
  export LAST_CHANCE_MATCHES_TO_REVIEW="$songsFile.matchesToReview.txt"
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

  echo "Inserting songs from $songsFile in $SQLITEDB..."
}

######### Main ##########

initialize "$@"
datacheck

while read filePath; do
  # important to trim files from \r and \n !!!!!
  filePath=$(echo $filePath| tr -d '\n' | tr -d '\r' )
  getPairFile_result="$TMP_DIRECTORY/getPairFile_lastResult"
  # Parse only lines that contain .mp3 or .flac/m4a files and not #recycle and @eadir
  if echo "$filePath" | grep -i 'mp3\|flac\|m4a' | grep -i -v '#recycle\|@eaDir' > /dev/null ; then
    $GET_PAIR_FILE_SCRIPT_PATH -d $useLastChanceMatchOption -s "$filePath" -o "$getPairFile_result"
    # Handle main file not found error
    [ $? -eq 100 ] && {  countMainFilesNotFound=$((countMainFilesNotFound + 1)) ; }
    # Update stats and debug logs
    while read pair_res ; do
      if [[ -z "$pair_res" ]]
      then
        # pair song was not found
        countPairFilesNotFound=$((countPairFilesNotFound + 1))
      fi
    done < "$getPairFile_result"
  fi
done < "$songsFile"

echo "number of pair files not found from playlist: $countPairFilesNotFound"
echo "number of files not found from beets: $countMainFilesNotFound"

endProg 0
