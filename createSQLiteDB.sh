#!/bin/bash
# May be easily converted to sh compatible script if needed, since a very few bashisms are used ([[]]...)

# Synopsis :
#     Low level script.
#     Create the SQLLiteDB used to store pair files and playlists.
#
# Usage: Run command ./createSQLiteSB.sh --help
#
# Return codes:
#             0: Everything went fine
#             1: Wrong usage of the command
#
# Pre-requisites:
#   SQLite installed
#
# External dependencies:
    source ./utils.sh
#   geopts for input parameters parsing
#
#
# History
# Date            Version        Auteur        Commentaire
# 13/07/2017      1.0            Djhibee        Creation
#
####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################

####### Global variables #######

######## Shell variables ##########
debug_mode=0

#######################
# END OF CONFIGURATION
#######################

## Other constants and variables
#################################
SQL_SCRIPT_PATH="$SCRIPTS_DIRECTORY/createSQLiteDB.sql"
#######################


function usage {
  echo "USAGE: $0  [-f dbFileName] [-h]
             -f: Name of the DB file to generate
             -h --help : Display this message
        "
  exit 0
}

# Set shell attributes and initialize output files
function initialize {
  if [[ $1 =~ ^--help ]]; then
    usage
  fi
  if [ "$debug_mode" -eq 1 ]; then
    echo "debug mode is ON"
  else
    echo "debug mode is OFF"
  fi
  dbFile="$SQLITEDB"
  while getopts "f:h" option
  do
    case $option in
      h)
        usage
        ;;
      f)
        dbFile="$OPTARG";
        ;;
      :)
        endProg 1 "Option $OPTARG needs an argument" ;
        ;;
      \?)
        endProg 1 "$OPTARG : invalid option" ;
        ;;
    esac
  done

  echo "Creating SQLITE DB in $dbFile"
}

######### Main ##########

initialize "$@"

sqlite3 "$dbFile" < $SQL_SCRIPT_PATH

endProg 0
