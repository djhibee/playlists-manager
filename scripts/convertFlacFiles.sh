#!/bin/bash
# May be easily converted to sh compatible script if needed, since a very few bashisms are used ([[]]...)
#
# Synopsis:
#       Highest level script.
#       Convert Flac files to another format. For mp3 format,use lame V0 quality
#       Better to use Beets convert plugin (http://beets.readthedocs.io/en/v1.4.6/plugins/convert.html) if you can
#
# Usage: bash ./convertFlacFiles.sh -h
#
# Pre-requisites:
#
## External dependencies:
    source ${BASH_SOURCE%/*}/../SETTINGS
    source ${BASH_SOURCE%/*}/utils.sh
#   lame library
#   sox library
#   avconv
#
# Algo:
# Get all playlists in FLAC_DIRECTORY
#   -> convert To Mp3 in MP3_DIRECTOY
#
# History
# Date            Version        Auteur        Commentaire
# 05/08/2017      0.2           Djhibee       Creation DRAFT
# 30/12/2017      1.0           Djhibee       Creation

####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################

# Default directory for flac files to convert
SOURCE_DIRECTORY_DEFAULT="$PROJECT_DIRECTORY/tests/flacToConvert"
# Default directory for generated mp3 files
OUTPUT_DIRECTORY_DEFAULT="$PROJECT_DIRECTORY/tests/generatedMp3"
debug_mode=${debug_mode:-0}

#######################
# END OF CONFIGURATION
#######################
#######################
## Other variables
#######################
MP3_FORMAT="mp3"
APPLE_LOSSLESS="m4a"

##############################################
function usage {
  echo "USAGE: $0 [-h] [-d flacDirectory] [-o mp3Directory] [-f outputFormat]
             -h --help : Display this message
             -i: Directory for flac files to convert ($SOURCE_DIRECTORY_DEFAULT)
             -o: Output directory for generated mp3 files ($MP3_CONVERTED_DIRECTORY_DEFAULT)
             -f: mp3 or m4a for
                - Mp3 using lame V0 quality
                - Apple lossless
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
  sourceDirectory="$SOURCE_DIRECTORY_DEFAULT"
  outputDirectory="$OUTPUT_DIRECTORY_DEFAULT"
  outputFormat="$MP3_FORMAT"
  while getopts "hi:o:f:" option
  do
    case $option in
      h)
        usage
        ;;
      i)
        sourceDirectory="$OPTARG"
        ;;
      o)
        outputDirectory="$OPTARG"
        ;;
      f)
        outputFormat="$OPTARG"
        ;;
      :)
        endProg 1 "Option $OPTARG needs an argument" ;
        ;;
      \?)
        endProg 1 "$OPTARG : invalid option" ;
        ;;
    esac
  done

  #remove suffixe /
  sourceDirectory=${sourceDirectory%/}
  outputDirectory=${outputDirectory%/}
  log "Source directory: $sourceDirectory"
  log "Output directory: $outputDirectory"

  [ ! -d "$outputDirectory" ] && { mkdir "$outputDirectory" ; }
}


##########
#  Main
##########
initialize "$@"

pwd=`pwd`
FILES_TMP="$TMP_DIRECTORY/files.tmp"
find "$sourceDirectory" -type f > "$FILES_TMP"
while read file ; do
  log "next file: $file"
  dir=$(dirname "$file")
  log "dir: $dir"
  # remove sourcedirectory prefix from dirname using string substitution
  dir=${dir#$sourceDirectory}
  # remove potential / prefix
  # we must do the 2 substitutions  in 2 steps because of the case when file
  # are in sourcedirectory root (not in a subfolder).
  dir=${dir#/}
  filename=$(basename "$file")
  log "FileName: $filename"
  log "dir cleaned: $dir"
  if [ ${outputDirectory:0:1} == "/" ]; then
    outdir="$outputDirectory/$dir"
  else
    outdir="$pwd/$outputDirectory/$dir"
  fi
  log "outdir:$outdir"

  if [ -f "$file" ]
  then
    #set -x
    mkdir -p "$outdir"
    # we convert only flac music files
    if echo "$file" | grep -i 'flac$' > /dev/null ; then
      if [[ "$outputFormat" = "$APPLE_LOSSLESS" ]]
      then
        echo "CONVERTION TO APPLE LOSSLESS NOT IMPLEMENTED YET"
      else
        #sox "$i" -G -b 16 "$outdir/$filename" rate -v -L 44100 dither
        avconv -i "$file" -codec:a libmp3lame -q:a 0 "$outdir/${filename%.flac}.mp3"
      fi
      if [ $? -eq 0 ]; then
        echo "$outdir/$filename" created successfully
      else
        endProg -1 "Error creating $outdir/$filename. Stopping."
      fi
    else
      # duplicate non music files (cover...) to converted folder
      cp "$file" "$outdir/$filename"
    fi
  fi
done < "$FILES_TMP"

rm -f "$FILES_TMP"

endProg 0
