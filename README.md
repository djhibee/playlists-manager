# playlists-manager
Bash scripts to manage multi quality music libraries and their playlists.  
Works with Synology's Audio Station.  

## Context
  I use two music libraries. One for lossy files and one for lossless files.  
Thus, at home with high bandwidth, I can enjoy my lossless files, and on remote (in my car...) I can spare data in my phone's subscription by using corresponding lossy files.  
Of course, music players (DS Audio..) provide automatic transcoding but we have no visibility on the quality of the transcode and it uses music server's resources. Since the price/Go is low , having 2 files is not a problem anymore.  

  I call "pair file" the same song from a file encoded with another quality.Namely toto.mp3 is the pair file of toto.flac.  
Two pair files are either a "perfect match", namely coming from the same album, or a "last chance match", namely the song is the same but albums are not (compilation, re-edition...).  
The issue with such an approach is that I have to maintain 2 copies of the same playlist, the lossy one and the lossless one.  
However, music organiser (except Roon) are not able to match files with different quality. This is why I have created a bunch of scripts to automatise that.  

It uses the power of Beets library to identify pairs via tags compare.  
The scripts also give the possibility to embed playlist names directly into files tags, without tracing the play order though (via Beets again).  
At the end, I will have two copies per playlist:  
   - a "minimum quality" one prioritarizing lossy files when available, to play on remote  
   - and a "best quality" one prioritarizing lossless files when available, to play at home  

  I chose to do it with shell scripts to refresh my knowledge in bash but a better way to include it in the Beet ecosystem would have been to code it in python (easy to translate though) and create a beet plugin.  


## To start:

- Read scripts/updateAllPlaylists.sh. This is the highest level script.

## Authors

* **Djhibee** - *Initial work* -

See also the list of [contributors](https://github.com/djhibee/playlists-manager/contributors) who participated in this project.

## License

This project is licensed under the GNU General Public License - see the [LICENSE.md](https://github.com/djhibee/playlists-manager/blob/master/LICENSE) file for details

## Acknowledgments
