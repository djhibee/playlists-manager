#!/bin/bash

# Synopsis :
#       Lowest level script.
#       Export the SQLite music DB to a csv file in order to read it easily
#
# Usage: Run command ./exportMusicDBToCSV.sh --help
#
# Return codes:
#             0: Everything went fine
#             200: dbFile provided is not a file
#
# Pre-requisites:
#       BEWARE when exporting the csv file and opening it with excel.
#       When you try to open a text file or a comma-separated variable (CSV) file, you may receive the following error message:
#       SYLK: File format is not valid
#      Cause:
#        This problem occurs when you open a text file or CSV file and the first two characters of the file are the uppercase letters "I" and "D".
#        For example, the text file may contain the following text:
#
#        ID, STATUS
#        123, open
#        456, closed
#
#      Workaround
#        To open your file in Excel, open the file in a text editor, and then insert an apostrophe at the beginning of the first line of text.
#
# More explanation there: https://support.microsoft.com/en-gb/help/323626/sylk-file-format-is-not-valid-error-message-when-you-open-file
#
# External dependencies:
      source ${BASH_SOURCE%/*}/../SETTINGS
      source ${BASH_SOURCE%/*}/utils.sh
#   geopts for input parameters parsing
#
# History
# Date            Version        Auteur        Commentaire
# 06/07/2017      1.0            Djhibee       Creation

####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################
debug_mode=${debug_mode:-0}
# the default output file where to store the db export
OUTPUT_FILE_DEFAULT="$VAR_DIRECTORY/musicDB-export.txt"
#######################
# END OF CONFIGURATION
#######################
#########################
## Other variables
#########################

usage="USAGE: $0 [-h] [-d dbFile] [-o outputFile]

           -d : original music sqlite db to export
           -h --help : Display this message
           -o : file where to store the csv export

"

function usage {
  echo "$usage"
  exit 0
}

function datacheck {
    if [[ ! -f $dbFile ]]
    then
       endProg 200 ": $dbFile is not a file."
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
  __resultvar="$OUTPUT_FILE_DEFAULT"
  dbFile="$SQLITEDB"
  while getopts "hd:o:" option
  do
    case $option in
      d)
        dbFile="$OPTARG";
        # important to trim files from \r and \n !
        dbFile=$(echo $dbFile| tr -d '\n' | tr -d '\r' )
        ;;
      h)
        usage
        ;;
      o)
        __resultvar="$OPTARG"
        ;;
      :)
        endProg 1 "Option $OPTARG needs an argument" ;
        ;;
      \?)
        endProg 1 "$OPTARG : invalid option" ;
        ;;
    esac
  done
}

# "" are mandatory otherwise parameters will be split by space
initialize "$@"
datacheck

# we use the "here document" so that we dont have to create a dummy file containing the sqlite instructions
sqlite3 "$dbFile" <<!
.headers off
.mode csv
.output $__resultvar
select * from FILES;
!

endProg 0
