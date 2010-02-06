#! /bin/bash
#
# - iTunes must be running before you run this script
# - you will need to have the correct file permissions for copying tracks

itunes=`ps aux | grep -v grep | grep "/Applications/iTunes.app/Contents/MacOS/iTunes"`
if [ "$itunes" == "" ]; then
	echo "error: iTunes is not running"
	exit
fi

library_path=`osascript -e "
	tell application \"iTunes\"
		set loc to get location of track 1 of library playlist 1
		loc
	end tell" | sed 's/^.*:Users/:Users/;s/:/\//g;s/^\(.*iTunes Music\).*/\1/'`

get_tracks_count(){
	echo `osascript -e "
		tell application \"iTunes\"
			if \"$1\" = \"kind\" then 
				set c to get count (tracks of library playlist 1 whose kind contains \"$2\") 
			end if
			if \"$1\" = \"bitrate\" then 
				set c to get count (tracks of library playlist 1 whose bit rate equals $2) 
			end if
			if \"$1\" = \"genre\" then
				script o
					property genres : \"\"
				end script
				tell application \"iTunes\"
					if \"$2\" = \"genres\" then
						set o's genres to (get genre of tracks of library playlist 1)
					else
						set o's genres to (get genre of tracks of library playlist 1 whose genre contains \"$2\")
					end if
				end tell
				if \"$2\" = \"genres\" then
					set genreList to {}
					repeat with i from 1 to count o's genres
						set g to item i of o's genres
						if g is not in genreList then set end of genreList to g
					end repeat
					set c to count(genreList)
				else
					set c to count(o's genres)
				end if
			end if
			c
		end tell"`
}

library_overview(){
	clear

	echo 'Getting file list, please wait..'
	total_files=`osascript -e 'tell application "iTunes" to get count of tracks'`
	
	echo 
	echo "------"
	echo  "Library overview"
	echo "------"
	echo -e "$total_files \tTotal files"
	total_wav="$(get_tracks_count kind WAV)"
	echo -e "$total_wav \tWAV"
	total_aac="$(get_tracks_count kind AAC)"
	echo -e "$total_aac \tAAC"
	total_mpeg="$(get_tracks_count kind MPEG)"
	echo -e "$total_mpeg \tMPEG"
	total_other=$(($total_files - $total_wav - $total_aac - $total_mpeg))
	echo -e "$total_other \tOther"
	total_genre="$(get_tracks_count genre genres)"
	echo -e "$total_genre \tGenres"

	echo 
	echo "------"
	echo "MPEG Bitrates"
	echo "------"
	total_bitrate_128="$(get_tracks_count bitrate 128)"
	echo -e "$total_bitrate_128 \t128kbps"
	total_bitrate_160="$(get_tracks_count bitrate 160)"
	echo -e "$total_bitrate_160 \t160kbps"
	total_bitrate_192="$(get_tracks_count bitrate 192)"
	echo -e "$total_bitrate_192 \t192kbps"
	total_bitrate_224="$(get_tracks_count bitrate 224)"
	echo -e "$total_bitrate_224 \t224kbps"
	total_bitrate_256="$(get_tracks_count bitrate 256)"
	echo -e "$total_bitrate_256 \t256kbps"
	total_bitrate_320="$(get_tracks_count bitrate 320)"
	echo -e "$total_bitrate_320 \t320kbps"
	
	echo 
	echo "------"
	echo "Filesystem overview"
	echo "------"
	total_size=`du -sh "$library_path"`
	echo -e "$total_size"
        directories_count=`find "$library_path" -d -maxdepth 4 | wc -l | tr -d ' '`
	echo -e "$directories_count \tdirectories" 

	echo 
	echo -n "<any key to continue>"
	read
}

convert_aac(){
	echo -n "Converting AAC, please wait.."
	osascript -e '
	with timeout of 30 minutes
		tell application "iTunes" 
			set oldencoder to name of current encoder
			set current encoder to encoder \"$1\"
			convert (tracks whose kind contains "AAC")
			set current encoder to encoder oldencoder
		end tell
	end timeout ' &> /dev/null
	echo "done!"

	delete_aac
}

delete_aac(){
	echo -n "Deleting AAC, please wait.."
	osascript -e '
	with timeout of 30 minutes
		tell application "iTunes" 
			delete (tracks whose kind contains "AAC")
		end tell
	end timeout ' &> /dev/null
	echo "done!"
	echo 
	echo -n "<any key to continue>"
	read
}

convert_wav(){
	echo -n "Converting WAV, please wait.."
	osascript -e '
	with timeout of 30 minutes
		tell application "iTunes"
			set oldencoder to name of current encoder
			set current encoder to encoder \"$1\"
			convert (tracks whose kind contains "WAV")
			set current encoder to encoder oldencoder
		end tell
	end timeout' &> /dev/null

	echo "done!"

	delete_wav
}

delete_wav(){
	echo -n "Deleting WAV, please wait.."
	osascript -e '
	with timeout of 30 minutes
		tell application "iTunes" 
			delete (tracks whose kind contains "WAV")
		end tell
	end timeout ' &> /dev/null
	echo "done!"
	echo 
	echo -n "<any key to continue>"
	read
}

convert_tracks(){
	clear

	echo "Check your iTunes.."

	answer_type=`osascript -e '
		tell application "iTunes"
			set targettype to (choose from list { "WAV audio file", "AAC audio file" } with prompt "Type of track to convert:" OK button name "Choose" without multiple selections allowed and empty selection allowed) as string
			targettype
		end tell
		'`

	if [ "$answer_type" != "false" ]; then

		answer_encoder=`osascript -e "
			tell application \"iTunes\"
				set oldencoder to name of current encoder
				set allencoders to name of every encoder
				set newencoder to (choose from list allencoders with prompt \"Please Choose an encoder\" OK button name \"Choose\" without multiple selections allowed and empty selection allowed) as string
				newencoder
			end tell
			"`
		if [ "$answer_encoder" != "false" ]; then
			echo
			if [ "$answer_type" == "WAV audio file" ]; then
				convert_wav "$answer_encoder"
			fi
			if [ "$answer_type" == "AAC audio file" ]; then
				convert_aac "$answer_encoder"
			fi
		fi
	fi
}


remove_directories(){
	clear

	echo "Getting directory list, please wait.."
	
	directories=`find "$library_path" -d -empty -maxdepth 4`
	count_directories=`echo "$directories" | wc -l`
	size_directories=`echo "$directories" | du -sh`

	echo 
	
	echo "found $count_directories empty directories using $size_directories"
	
	if [ $count_directories -gt 0 ]; then

		echo 

		echo -n "Delete all? [y/n]: "

		read answer_deleteall

		if [ $answer_deleteall == "y" ]; then
			IFS=$'\n'
			files=($directories)
			filenum=1
			for dir in "${files[@]}"
			do
				rm -r "$dir"
				echo -n "."
			done
			echo "all done!"
		else 
		
			echo -n "Delete one by one? [y/n] "
		
			read answer_deleteone

			if [ $answer_deleteone == "y" ]; then
				IFS=$'\n'
				files=($directories)
				filenum=1
				for dir in "${files[@]}"
				do
					echo -n "Delete $dir? [y/n] "
					read answer_deletedir
					if [ $answer_deletedir == "y" ]; then
						rm -r "$dir"
					fi
				done
				echo "all done!"
			fi
		fi
	fi	
	echo 
	echo -n "<any key to continue>"
	read
}

get_tracks_by() {
	itemType=$1
	search=$2
	# get the list of matching items
	items=`osascript -e "
		tell application \"iTunes\" 
			script o
				property matches : \"\"
			end script
			if \"$itemType\" = \"artist\" then set o's matches to (get artist of tracks of library playlist 1 whose artist contains \"$search\")
			if \"$itemType\" = \"genre\" then set o's matches to (get genre of tracks of library playlist 1 whose genre contains \"$search\")
			set genreList to {}
			repeat with i from 1 to count o's matches
				set g to item i of o's matches
				if g is not in genreList then set end of genreList to g
			end repeat
			genreList
		end tell
	"`
	IFS=","
	set -- $items
	itemsArr=( $items )

	echo -n "Found ${#itemsArr[@]} matcing $itemType"; echo "s: "
	echo

	for item in ${itemsArr[@]}; do
		echo "$item" | sed 's/^ //;s/ $//'
	done

	echo
	echo -n "enter the correct $itemType: "
	read answer_itemtype
	echo
	
	ids=`osascript -e "
		tell application \"iTunes\" 
			script o
				property ids : \"\"
			end script
			if \"$itemType\" = \"artist\" then set o's ids to (get id of tracks of library playlist 1 whose artist equals \"$answer_itemtype\")
			if \"$itemType\" = \"genre\" then set o's ids to (get id of tracks of library playlist 1 whose genre equals \"$answer_itemtype\")
			set idList to {}
			repeat with i from 1 to count o's ids
				set g to item i of o's ids
				if g is not in idList then set end of idList to g
			end repeat
			idList
		end tell
	"`
	IFS=", "
	set -- $ids
	id_list=( $ids )
}

copy_tracks() {

	clear

	echo "This feature will copy tracks to specified location in order of \$PATH/Genre/Artist/Album/Track"

	path=""
	try=0

	while [ ! -d "$path" ] && [ $try -lt 3 ]; do
		echo -n "Enter path to copy to: "

		read path

		if [ ! -d "$path" ]; then
			echo "invalid path!"
			try=$[ $try + 1 ]
		fi
	done

	if [ -d "$path" ]; then

		echo -n "Copy by [g]enre, [a]rtist, [A]ll: "

		read answer_copytype

		id_list=''

		# get tracks by artist
		if [ $answer_copytype == "a" ]; then
			found_artist='0'
			try=0

			while [ $found_artist == '0' ] && [ $try -lt 3 ]; do
				echo -n "Enter artist: "
				read answer_artist

				# search for a valid artist
				found_artist=`osascript -e "tell application \"iTunes\" to get count (tracks whose artist contains \"$answer_artist\")"`

				if [ $found_artist == '0' ]; then
					echo "artist not found!"
					try=$[ $try + 1 ]
				fi
			done
			
			if [ $found_artist != '0' ]; then
				get_tracks_by "artist" "$answer_artist"
			fi

		fi
		
		# get tracks by genre
		if [ $answer_copytype == "g" ]; then
			found_genre='0';
			try=0

			while [ $found_genre == '0' ] && [ $try -lt 3 ]; do
				echo -n "Enter genre: "
				read answer_genre

				# search for a valid genre
				found_genre=`osascript -e "tell application \"iTunes\" to get count (tracks whose genre contains \"$answer_genre\")"`

				if [ $found_genre == '0' ]; then
					echo "genre not found!"
					try=$[ $try + 1 ]
				fi
			done

			if [ $found_genre != '0' ]; then
				get_tracks_by "genre" "$answer_genre"
			fi
		fi

		# get all tracks
		if [ $answer_copytype == "A" ]; then
			ids=`osascript -e "
				tell application \"iTunes\" 
					script o
						property ids : \"\"
					end script
					tell application \"iTunes\"
						set o's ids to (get id of tracks of library playlist 1)
					end tell
					set idList to {}
					repeat with i from 1 to count o's ids
						set g to item i of o's ids
						if g is not in idList then set end of idList to g
					end repeat
					idList
				end tell
			"`
			IFS=", "
			set -- $ids
			id_list=( $ids )
		fi

		if [ $answer_copytype == "a" ] || [ $answer_copytype == "g" ] || [ $answer_copytype == "A" ]; then

			echo "Copying tracks, this might take a long time.."

			c=1

			for track_id in ${id_list[@]}; do
				
				cd "$path"

				tr=`osascript -e "
					tell application \"iTunes\" 
						set ge to (get genre of tracks whose id equals $track_id)
						set ar to (get artist of tracks whose id equals $track_id)
						set al to (get album of tracks whose id equals $track_id)
						set lo to (get location of tracks whose id equals $track_id)
						ge & ar & al & lo
					end tell
					"`

				echo "$tr"

				exit
				IFS=", "
				set -- $tr
				track=( $tr )

				genre_filename=`echo "${track[0]}" | sed 's/\\//|/g'`
				mkdir "$genre_filename" &> /dev/null
				cd "$genre_filename"
				
				artist_filename=`echo "${track[1]}" | sed 's/\\//|/g'`
				mkdir "$artist_filename" &> /dev/null
				cd "$artist_filename"
				
				album_filename=`echo "${track[2]}" | sed 's/\\//|/g'`
				mkdir "$album_filename" &> /dev/null
				cd "$album_filename"

				trackpath=`echo "${track[3]}" | sed 's/^.*:Users/:Users/;s/:/\//g'`
				filename=${trackpath##*/}

				echo "${track[2]}"

				echo "$trackpath"
				echo "$filename"

				exit

				if [ ! -f "$filename" ]; then
					cp "$trackpath" "$filename"
				fi

				echo "$c of ${#id_list[@]} - $trackpath"
				c=$((c+1))
			done

			echo
			echo "All done!"
			echo 
			echo -n "<any key to continue>"
			read
		fi
	fi
}

while : ; do
	clear
	cat << !
MENU
------
1. Library Overview
2. Convert Tracks
3. Copy Tracks
4. Remove empty directories
5. Exit
------
!
	echo -n "option: "

	read choice

	case $choice in
		1) library_overview ;;
		2) convert_tracks ;;
		3) copy_tracks ;;
		4) remove_directories ;;
		5) exit ;;
		*) sleep 1 ;;
	esac
done
