#!/bin/bash
#
# Synopsis :
#           Script to copy album covers to another name.
#           To use when Beets raise an error because file does not exists anymore.
#
# Usage:    Run correctCoversName.sh --help
#
# External dependencies:
    source ${BASH_SOURCE%/*}/../SETTINGS
    source ${BASH_SOURCE%/*}/utils.sh

####################################
## TO CONFIGURE BEFORE USING SCRIPT
####################################

####### Global variables #######

######## Shell variables ##########
debug_mode=${debug_mode:-0}
#######################
# END OF CONFIGURATION
#######################


##############################################
function usage {
  echo "USAGE: $0 [-h] [-d musicDirectory]

             -d : Music Directory containing songs whose cover needs to be renamed
             -h --help : Display this message
        "
  exit 0
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
  musicDirectory=""
  while getopts "d:h" option
  do
    case $option in
      h)
        usage
        ;;
      d)
        musicDirectory="$OPTARG";
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


##########
#  Main
##########
initialize "$@"

find "$musicDirectory" -name cover.*.jpeg > "$TMP_DIRECTORY/theCovers.txt"
while read file; do
 echo oldName: "$file"
 newfile="${file/cover.*.jpeg/cover.jpeg}"
 echo newName: $newfile
 cp "$file" "$newfile"
done < "$TMP_DIRECTORY/theCovers.txt"

# Clean files
if [ "$debug_mode" -eq 0 ]; then
  rm -f "$TMP_DIRECTORY/theCovers.txt"
fi

endProg 0
