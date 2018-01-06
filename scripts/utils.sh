#!/bin/bash

# Synopsis :
#     Gather utility functions for all scripts (logging, constants...)
#
# Pre-requisites:
#
# External dependencies:
#
# History
# Date            Version        Auteur        Commentaire
# 18/03/2017      1.0            Djhibee       Creation
#
####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################

# Colors for logs
export RED_COLOR='\033[0;31m'
export GREEN_COLOR='\033[0;32m'
export NO_COLOR='\033[0m'
export LOG_COLOR_DEFAULT=$NO_COLOR

######## Shell variables ##########
debug_mode=1
# if 1, only look for pair files in DB, not with beets tags
only_use_db_for_pairs=1

#######################
# END OF CONFIGURATION
#######################

# Function called at the end of a program with exit status
function endProg {
    end=$1
    if [ $end -gt 0 ]; then
        echoInColor "End of script $0 with error $end:" "$RED_COLOR" >&2
        if [ $# -gt 1 ]; then
            shift 1 ;
            echoInColor "$*" "$RED_COLOR" | sed 's/^/    /' >&2
        fi
        exit $end
    else
        echoInColor "Script $0 ended normally" "$GREEN_COLOR"
        exit 0
    fi
}

# Print debug logs if debug_mode=1
function log {
  typeset logcolor
  if [ $# -gt 1 ]; then
  	logColor="$2"
  else
    logColor="$LOG_COLOR_DEFAULT"
  fi
  if [ "$debug_mode" -eq 1 ]; then
    echoInColor "$1" "$logColor"
  fi
}

# Echo a text with chosen color
function echoInColor {
  typeset echoColor
  if [ $# -gt 1 ]; then
    echoColor="$2"
  else
    echoColor="$LOG_COLOR_DEFAULT"
  fi
  echo -e "$echoColor$1"
  printf "${LOG_COLOR_DEFAULT}\r"
}
