#!/usr/bin/env bash

# This shell script will copy files from your iTunes directoy to a specified location in the
# the order of Genre/Artist/Album/Track1.mp3

path=$1
library="playlist 1"
allowed_folder_chars='s/[^a-zA-Z0-9/\&\.,\(\)\ ]/_/g'
filter_genre="Dubstep"

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

create_segment(){

	filename="$(get_track_info $1 $2)"
	filename=`echo $filename | sed "$allowed_folder_chars"`

	if [ ! "$filename" ]; then 

		filename="Unknown $1"
	fi

	mkdir -p "$filename" &> /dev/null

	echo $filename
}

on_exit_copy(){

	echo "exited"
}

setup(){

	if [ ! -d "$path" ]; then

		echo "invalid path!"

		echo "usage: ./itunes-utils-copy.sh PATH"

		exit
	fi

	clear

	echo -n "checking files. please wait.."
}

setup

total_tracks=`osascript -e "
       tell application \"iTunes\"
	      get count (tracks)
	end tell"`
no_genre_tracks=`osascript -e "
	tell application \"iTunes\"
		get count (tracks of library $library whose genre equals \"\")
	end tell"`
no_artist_tracks=`osascript -e "
	tell application \"iTunes\"
		get count (tracks of library $library whose artist equals \"\")
	end tell"`
no_album_tracks=`osascript -e "
	tell application \"iTunes\"
		get count (tracks of library $library whose album equals \"\")
	end tell"`
unknown_tracks=`osascript -e "
	tell application \"iTunes\"
		get count (tracks of library $library whose name contains \"unknown\" or artist contains \"unknown\" or album contains\"unknow\" or genre contains \"unknown\")
	end tell"`

total_size(){

	total_size=`osascript -e "
		with timeout of 300 seconds
			tell application \"iTunes\"
				script o
					property matches : \"\"
				end script
				set o's matches to (get size of tracks of library $library)
				set total to 0
				repeat with i from 1 to count o's matches
					set g to item i of o's matches
					set total to total + g as integer
				end repeat
			end tell
		end timeout"`

	echo "total size:$total_size"
}

echo "done"; 
echo

echo "$total_tracks Total tracks"

echo "$no_genre_tracks Tracks with no Genre set"

echo "$no_artist_tracks Tracks with no Artist set"

echo "$no_album_tracks Tracks with no Album set"

echo "$unknown_tracks 'Unknown' tracks"

echo
echo -n "building track list, please wait.."

ids=`osascript -e "
	with timeout of 300 seconds
		tell application \"iTunes\"
			script o
				property ids : \"\"
			end script
			tell application \"iTunes\"
				set o's ids to (get id of tracks of library $library)
			end tell
			set idlist to {}
			repeat with i from 1 to count o's ids
				set end of idlist to item i of o's ids
			end repeat
			idlist
		end tell
	end timeout
		"`
IFS=", "
set -- $ids
id_list=( $ids )

echo "done";
echo

echo -n "Do you want to start the copy? y/n: "

read answer_start

if [ $answer_start == 'y' ]; then 

	echo "Copying tracks, this might take a long time.."
	echo

	trap on_exit_copy EXIT

	start_time=`date +%s`

	c=1
	for track_id in ${id_list[@]}; do

		cd "$path"

		genre="$(create_segment genre $track_id)"; cd "$genre"
		artist="$(create_segment artist $track_id)"; cd "$artist"
		album="$(create_segment album $track_id)"; cd "$album"
		
		track_size="$(get_track_info size $track_id)"
		track_size="`echo \"$track_size/1024/1024\" | bc`MB"

		trackpath=`echo "$(get_track_info location $track_id)" | sed 's/^.*:Users/:Users/;s/:/\//g'`

		filename=${trackpath##*/}

		echo "$c of ${#id_list[@]} - $track_size - $genre/$artist/$album/$filename"

		if [ ! -f "$filename" ]; then

			cp "$trackpath" "$filename"
		fi

		c=$((c+1))
	done

	echo
	echo "All done!"

	end_time=`date +%s`

	time_diff=`echo \($end_time - $start_time\) | bc`

	echo "time: $time_diff seconds"

fi
