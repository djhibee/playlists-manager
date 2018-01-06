#!/bin/sh

# !!!!DRAFT!!!!
# Synopsis :
#           Script to copy album covers to another name.
#           To use when Beets raise an error because file does not exists anymore.
# Usage: ./covers.sh

DIRECTORY=/volume1/music/

find "$DIRECTORY" -name cover.*.jpeg > theCovers.txt
while read file; do
 echo oldName: "$file"
 newfile="${file/cover.*.jpeg/cover.jpeg}"
 echo newName: $newfile
 cp "$file" "$newfile"
done < theCovers.txt
