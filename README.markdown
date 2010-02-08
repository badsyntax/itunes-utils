This small bash script was built to help you manage your iTunes library.

* iTunes must be running before you run this script
* you will need to have the correct file permissions for copying tracks
* you'll need to `sudo chmod +x itunes-utils.sh` to run the script

Some of the features include:

* Viewing an overview of your library
* Convert Tracks (eg AAC to MP3)
* Creating a backup of your itunes library
  * You can copy tracks by genre, artist or all.
  * Tracks will be copied into a specified directory in the order of: Genre/Artist/Album/Track
* Remove duplicate tracks
  * Filter tracks by different criteria into a unique playlist where you can delete the duplicates
* Remove empty directories


All file modifications are run through iTunes using applescript.
