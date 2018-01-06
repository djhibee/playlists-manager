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

####### Global variables #######
# Playlist-manager root directory
export PROJECT_DIRECTORY="/Users/jchapeland/git_clones/playlists-manager"
# Directory where all music scripts are stored
export SCRIPTS_DIRECTORY="$PROJECT_DIRECTORY/scripts"
# Directory where all temporary files are stored
export TMP_DIRECTORY="$PROJECT_DIRECTORY/tmp"
# Directory where all outputfiles files are stored
export VAR_DIRECTORY="$PROJECT_DIRECTORY/var"
# Beets' config for lossy files
export CONFIG_LOSSY="$PROJECT_DIRECTORY/beetFiles/config.yaml"
# Beets' config for lossless files
export CONFIG_LOSSLESS="$PROJECT_DIRECTORY/beetFiles/config-lossless.yaml"
# DB were to store playlists and pairs
export SQLITEDB="$PROJECT_DIRECTORY/var/musicPairsAndPlaylists.db"
# Directory where manual playlists are stored (audio station playlists etc...)
export PLAYLIST_DIRECTORY_TO_BACKUP="$PROJECT_DIRECTORY/var/playlists"
# Directory where max quality and min quality playlists are generated
export GENERATED_PLAYLIST_DIRECTORY="$PROJECT_DIRECTORY/var/playlists-generated"
# Default directory for playlists generation
export PLAYLIST_DIRECTORY_DEFAULT=$PLAYLIST_DIRECTORY_TO_BACKUP
# Directory for lossy music files. Do not append a / at the end
export LOSSY_DIRECTORY=$( grep -E '^directory: ' $CONFIG_LOSSY  | sed 's/^directory: //' | sed 's/\/$//')
# Default directory for music files
export MUSIC_DIRECTORY_DEFAULT=$LOSSY_DIRECTORY
# Scripts paths
export UPDATE_FILE_COMMENTS_SCRIPT_PATH="$SCRIPTS_DIRECTORY/updateFileComments.sh"
export GET_PAIR_FILE_SCRIPT_PATH="$SCRIPTS_DIRECTORY/getPairFile.sh"
export GENERATE_RATING_PLAYLIST_SCRIPT_PATH="$SCRIPTS_DIRECTORY/generateRatingPlaylist.sh"
export UPDATE_MUSIC_FILES_AND_SQLDB_SCRIPT_PATH="$SCRIPTS_DIRECTORY/updatePlaylist.sh"
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
