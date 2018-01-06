#!/bin/bash
####
# Check if order of songs changed or if we just added/removed songs at the end of the playlist.
# In the last case (most common), we can avoid a full playlist overwrite and so improve perfs.
# Only work if using DB since backup files don't maintain songs orders
# diff <(head -n 5 fileA.txt) <(head -n 5 fileD-song-added-in-middle.txt) -U 0 | grep -e "^\+[^+]"
echo $1
#set -x
backupLength=`wc -l < $2 | sed -e 's/^[ \t]*//'`
playlistLength=`wc -l < $1 | sed -e 's/^[ \t]*//'`
minLenght=$(($backupLength<$playlistLength?$backupLength:$playlistLength))
comm -3 <(head -n $minLenght "$1") <(head -n $minLenght "$2") | sed '/#EXTINF:/d'  > "toto.checkOrderChange"
if [[ -s toto.checkOrderChange ]] ; then
  echo "Playlist song orders changed, we need to rebuild the full playlist"
else
  echo "Playlist changes were at the end of the file, no need to rebuild the full playlist"
fi
set +x
