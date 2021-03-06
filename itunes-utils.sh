#! /bin/bash
#
# itunes.sh
# @auth richard willis


get_itunes_info(){
	# ensure itunes is running
	itunes=`ps aux | grep -v grep | grep "/Applications/iTunes.app"`
	if [ "$itunes" == "" ]; then
		echo "opening iTunes.."
		open /Applications/iTunes.app
	fi
	# find path to library on the filesystem
	library_path=`osascript -e "
		tell application \"iTunes\"
			set loc to get location of track 1 of library playlist 1
			loc
		end tell" | sed 's/^.*:Users/:Users/;s/:/\//g;s/^\(.*iTunes Music\).*/\1/'`
}

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
	echo -n "please wait.."
	total_size=`du -sh "$library_path"`
	echo -ne "\r              "
	echo -e "\r$total_size"

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
			activate
			tell browser window 1 to set visible to true
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

remove_duplicates(){
	clear

	echo "Check your iTunes.."

	# get criteria list
	answer_criteria=`osascript -e '
		property path_to_xml : "~/Music/iTunes/iTunes Music Library.xml"
		tell application "iTunes"
			activate
			tell browser window 1 to set visible to true
			choose from list {"Name", "Artist", "Album", "Genre", "Size", "Kind", "Bit Rate"} default items {"Name", "Artist", "Album", "Genre", "Size"} with prompt "Select criteria:" with multiple selections allowed without empty selection allowed
		end tell'`

	if [ "$answer_criteria" != "false" ]; then

		# convert string criteria list into perl list format
		answer_criteria=`echo "$answer_criteria" | sed "s/, /', '/g"`
		answer_criteria="'$answer_criteria'"

		echo
		echo "Searching for duplicate tracks, please wait.."
	
		# adapted from "Corral iTunes Dupes" by Doug Adams and Charles E.M. Strauss 
		tracks=`perl -e "
			@unique_tags=($answer_criteria);
			\\$/=undef;
			\\$s=<>;
			while(\\$s=~m:<key>(\d*)</key>(.*?)<dict>(.*?)</dict>:sg){
				(\\$db_id,\\$dict)=(\\$1,\\$3);
				while(\\$dict=~m:<key>(.*?)</key>(.*?)<(.*?)>(.*?)</\3>:sg){
					\\$h{\\$db_id}->{\\$1}=\\$4;
				}
			};
			@db_ids=keys %h;
			foreach \\$db_id (@db_ids){
				%f=%{\\$h{\\$db_id}};
				\\$uid=join'<>',@f{@unique_tags};
				push@{\\$uid_hash{\\$uid}},\\$db_id;
			}
			while((\\$uid,\\$key_list_ref)=each %uid_hash){
				@key_list=@{\\$key_list_ref};
				next unless@key_list>1;
				print\"( @key_list )\n\";
			}" ~/Music/iTunes/iTunes\ Music\ Library.xml`
		tracks_count=`echo "$tracks" | wc -l | tr -d ' '`

		if [ $tracks_count > 0 ]; then 
			# create the 'Duplicates' playlist
			osascript -e '
				tell application "iTunes"
					activate
						if (not (exists user playlist "Duplicates")) then make new playlist with properties {name:"Duplicates"}
					try
						delete every track of playlist "Duplicates"
					end try
					set view of front browser window to playlist "Duplicates"
				end tell'
			echo
			echo -n "Adding $tracks_count duplicate tracks to \"Duplicates\" playlist."
			IFS=$'\n'
			thetracks=($tracks)
			for track in "${thetracks[@]}"; do

				# munge the tracks ids
				track_ids=`perl -e "\\$string=\"$track\";\\$string =~ s/\( (.*) \).*/\\$1/;print\"\\$string\""` &> /dev/null
				
				# add duplicate tracks to playlist
				IFS=$' '
				theids=($track_ids)
				for id in "${theids[@]}"; do
					theid=`echo "$id" | sed 's/\.*//g'`
					osascript -e "
						set dbid to $theid as number
						tell application \"iTunes\"
							try 
								duplicate (first file track of library playlist 1 whose database ID is dbid) to playlist \"Duplicates\"
							end try
						end tell" &> /dev/null
					echo -n "."
				done
			done
			echo -n 'done!'
			echo; echo
			echo "You can now delete the duplicate tracks from the \"Duplicates\" playlist in iTunes."
		else 
			echo "No duplicate tracks found!"
		fi
		
		echo 
		echo -n "<any key to continue>"
		read
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

# filter tracks by artist or genre
get_tracks_by() {
	itemType=$1

	# get list of matching tracks
	items=`osascript -e "
		tell application \"iTunes\" 
			script o
				property matches : \"\"
			end script
			if \"$1\" = \"artist\" then set o's matches to (get artist of tracks of library playlist 1 whose artist contains \"$2\")
			if \"$1\" = \"genre\" then set o's matches to (get genre of tracks of library playlist 1 whose genre contains \"$2\")
			if \"$1\" = \"all\" then set o's matches to (get id of tracks of library playlist 1)
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
	echo -n "Enter the correct $itemType listed above: "
	read answer_itemtype
	echo
	
	# build list of track ids
	ids=`osascript -e "
		tell application \"iTunes\" 
			script o
				property ids : \"\"
			end script
			if \"$itemType\" = \"artist\" then 
				set o's ids to (get id of tracks of library playlist 1 whose artist equals \"$answer_itemtype\")
			end if
			if \"$itemType\" = \"genre\" then 
				set o's ids to (get id of tracks of library playlist 1 whose genre equals \"$answer_itemtype\")
			end if
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

get_track_info(){
	val=`osascript -e "
		tell application \"iTunes\"
			if \"$1\" = \"genre\" then set info to (get genre of tracks whose id equals $2)
			if \"$1\" = \"artist\" then set info to (get artist of tracks whose id equals $2)
			if \"$1\" = \"album\" then set info to (get album of tracks whose id equals $2)
			if \"$1\" = \"location\" then set info to (get location of tracks whose id equals $2)
			if \"$1\" = \"size\" then set info to (get size of tracks whose id equals $2)
			info
		end tell" | sed 's/\\//|/g'`
	val=${val## }
	val=${val%% }
	echo "$val"
}

copy_tracks() {
	clear

	echo "This feature will copy tracks to specified location in order of \$PATH/Genre/Artist/Album/Track"

	path=""
	try=0

	if [ -z $2 ]; then

		while [ ! -d "$path" ] && [ $try -lt 3 ]; do
			echo -n "Enter path to copy to: "
	
			read path
	
			if [ ! -d "$path" ]; then
				echo "invalid path!"
				try=$[ $try + 1 ]
			fi
		done
	else 
		path=$2
	fi

	if [ -d "$path" ]; then

		if [ "$1" != "--all" ]; then

			echo -n "Copy by [g]enre, [a]rtist, [A]ll: "

			read answer_copytype

		else
			answer_copytype=$1
			if [ "$answer_copytype" == "--all" ]; then
				answer_copytype="A"
			fi
		fi

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
			echo "Building track list, please wait.."
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
						set end of idList to item i of o's ids
					end repeat
					idList
				end tell
			"`
			echo 
			IFS=", "
			set -- $ids
			id_list=( $ids )
		fi

		if [ $answer_copytype == "a" ] || [ $answer_copytype == "g" ] || [ $answer_copytype == "A" ]; then

			echo "Copying tracks, this might take a long time.."

			c=1
			for track_id in ${id_list[@]}; do
				
				cd "$path"

				# create directories
				genre_filename="$(get_track_info genre $track_id)"
				mkdir -p "$genre_filename" &> /dev/null; cd "$genre_filename"
				
				artist_filename="$(get_track_info artist $track_id)"
				mkdir -p "$artist_filename" &> /dev/null; cd "$artist_filename"
				
				album_filename="$(get_track_info album $track_id)"
				mkdir -p "$album_filename" &> /dev/null; cd "$album_filename"

				track_size="$(get_track_info size $track_id)"
				track_size="`echo \"$track_size/1024/1024\" | bc`MB"

				trackpath=`echo "$(get_track_info location $track_id)" | sed 's/^.*:Users/:Users/;s/:/\//g'`
				filename=${trackpath##*/}
				
				echo "$c of ${#id_list[@]} - $track_size - $trackpath"

				# copy track
				if [ ! -f "$filename" ]; then
					cp "$trackpath" "$filename"
				fi

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

show_help(){
	echo -e "Usage:\titunes-utils.sh [action] ...";
	echo -e "\titunes-utils.sh [option] [path] ...";
	echo -e "Options:"
	echo -e "\t--help"
	echo -e "\t--copy"
	echo -e "\t--all"
}

copy_tracks_cli(){
	if [ -z $1 ]; then
		show_help
	else 
		if [ "$1" == "--all" ] && [ "$2" != "" ] ; then
			copy_tracks "$1" "$2"
		else 
			echo "error: invalid path!"
			echo
			show_help
		fi	
	fi
}

# check for arguments
if [ $# != 0 ]; then 
	case "$1" in
		"--help") show_help ;;
		"--copy") copy_tracks_cli $2 $3 ;;
		*) ;;
	esac
	exit
fi

while : ; do
	clear
	cat << !
MENU
------
1. Library Overview
2. Convert Tracks
3. Copy Tracks
4. Remove duplicates
5. Remove empty directories
6. Exit
------
!
	echo -n "option: "

	read choice

	case $choice in
		1) library_overview ;;
		2) convert_tracks ;;
		3) copy_tracks ;;
		4) remove_duplicates ;;
		5) remove_directories ;;
		6) exit ;;
		*) sleep 1 ;;
	esac
done
