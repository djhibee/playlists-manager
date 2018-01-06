#!/bin/sh

# !!!!!!!DRAFT!!!!!!!!
# script example to convert  directories/files to MACOS' utf8 format
# REQUIRES iconv library

 file="/music_mp3/Beyonce/4 [2011]/09_Beyoncé_-_4_[2011]-_Countdown.mp3"
 beet -v -c ~/.config/beets/config-mp3-toProcess.yaml list path:"`iconv -f utf-8 -t utf-8-mac <<< "$file"`"
