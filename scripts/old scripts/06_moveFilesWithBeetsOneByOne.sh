#!/bin/sh

#### !!!!!DRAFT!!! But working...
# Move one by one each file from a repo using Beets' move command

CONFIG_MUSIC_TO_PROCESS="/Users/superToto/.config/beets/config-mp3-toProcess.yaml"

beet -c $CONFIG_MUSIC_TO_PROCESS list -p /Volumes/SuperToto_MOB/music-mp3-v0/Compilations/Vrac/ > tmp
while read file; do
  echo "Processing $file"
  beet -c $CONFIG_MUSIC_TO_PROCESS move path:"$file"
done < tmp
