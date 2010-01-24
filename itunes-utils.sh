#! /bin/bash
# notes:
# - iTunes must be running before you run this script
# - iTunes encoder must set to 'MP3 encoder' (Preferences >> Import Settings)

itunes=`ps aux | grep -v grep | grep "/Applications/iTunes.app/Contents/MacOS/iTunes"`
if [ "$itunes" == "" ]
then
	echo "error: iTunes is not running"
	exit
fi

library_overview() {

	echo 'Getting file list, please wait..'

	total_files=`osascript -e 'tell application "iTunes" to get count of tracks'`
	
	echo 

	echo "------"

	echo  "Library overview"

	echo "------"

	echo -e "$total_files \tTotal files"

	total_wav=`osascript -e 'tell application "iTunes" to (count(tracks whose kind contains "WAV"))'`
	echo -e "$total_wav \tWAV"

	total_aac=`osascript -e 'tell application "iTunes" to (count(tracks whose kind contains "AAC"))'`
	echo -e "$total_aac \tAAC"

	total_mpeg=`osascript -e 'tell application "iTunes" to (count(tracks whose kind contains "MPEG"))'`
	echo -e "$total_mpeg \tMPEG"

	total_other=$(($total_files - $total_wav - $total_aac - $total_mpeg))
	echo -e "$total_other \tOther"

	total_genre=`osascript -e "
	script o
	   property genres : \"\"
	end script
	tell application \"iTunes\"
	   set o's genres to (get genre of tracks of library playlist 1)
	end tell
	set genreList to {}
	repeat with i from 1 to count o's genres
	   set g to item i of o's genres
	   if g is not in genreList then set end of genreList to g
	end repeat
	count(genreList)"`

	echo -e "$total_genre \tGenres"

	echo 

	echo "------"

	echo "MPEG Bitrates"

	echo "------"

	total_bitrate_128=`osascript -e 'tell application "iTunes" to (count(tracks whose bit rate equals 128))'`
	echo -e "$total_bitrate_128 \t128kbps"

	total_bitrate_160=`osascript -e 'tell application "iTunes" to (count(tracks whose bit rate equals 160))'`
	echo -e "$total_bitrate_160 \t160kbps"

	total_bitrate_192=`osascript -e 'tell application "iTunes" to (count(tracks whose bit rate equals 192))'`
	echo -e "$total_bitrate_192 \t192kbps"

	total_bitrate_224=`osascript -e 'tell application "iTunes" to (count(tracks whose bit rate equals 224))'`
	echo -e "$total_bitrate_224 \t224kbps"

	total_bitrate_256=`osascript -e 'tell application "iTunes" to (count(tracks whose bit rate equals 256))'`
	echo -e "$total_bitrate_256 \t256kbps"

	total_bitrate_320=`osascript -e 'tell application "iTunes" to (count(tracks whose bit rate equals 320))'`
	echo -e "$total_bitrate_320 \t320kbps"

	echo
}

convert_aac() {
	echo -n "Convert AAC? y/n: "

	read answer_convertaac

	if [ $answer_convertaac == "y" ]
	then
		echo -n "Converting AAC, please wait.."
		osascript -e '
		with timeout of 5 minutes
			tell application "iTunes" 
				convert(tracks whose kind contains "AAC")
			end tell
		end timeout
		' &> /dev/null
		echo "done!"

		delete_aac
	fi
}

delete_aac() {
	echo -n "Delete AAC? y/n: "

	read answer_deleteaac
	
	if [ $answer_deleteaac == "y" ]
	then
		echo -n "Deleting AAC, please wait.."
		osascript -e '
		with timeout of 5 minutes
			tell application "iTunes" 
				delete(tracks whose kind contains "AAC")
			end tell
		end timeout
		' &> /dev/null
		echo "done!"
	fi
}

convert_wav() {
	echo -n "Convert WAV? y/n: "

	read answer_convertwav

	if [ $answer_convertwav == "y" ]
	then
		echo -n "Converting WAV, please wait.."
		osascript -e '
		with timeout of 5 minutes
			tell application "iTunes"
				convert(tracks whose kind contains "WAV")
			end tell
		end timeout
		' &> /dev/null
		echo "done!"

		delete_wav
	fi
}

delete_wav() {
	echo -n "Delete WAV? y/n: "

	read answer_deletewav

	if [ $answer_deletewav == "y" ]
	then
		echo -n "Deleting WAV, please wait.."
		osascript -e '
		with timeout of 5 minutes
			tell application "iTunes" 
				delete(tracks whose kind contains "WAV")
			end tell
		end timeout
		' &> /dev/null
		echo "done!"
	fi
}

strip_comments() {
	echo -n "Strip comments? y/n "

	read answer_stripcomments

	batch_amount=500

	if [ $answer_stripcomments == "y" ]
	then
		echo "Stripping $total_files comments in batches of $batch_amount, please wait.."
		let batches=($total_files/$batch_amount)-1
		#for (( batch=0; batch<=$batches; batch++ ))
		#do
		#	let start_batch=($batch*$batch_amount)+1
		#	let end_batch=$start_batch+$batch_amount
		#	let st=$batch+1
			#echo -n -e "\rBatch $st of $batches.."
			osascript <<-EOT
			with timeout of 5 minutes
				tell application "iTunes" 
					set accumulator to do shell script "echo " without altering line endings
					repeat with t from 1 to 1250
						--set ln to do shell script "echo 'Track " & (location of (tracks t) as string) & "'" without altering line endings
						set ln to do shell script "echo 'Track '" without altering line endings
						set accumulator to accumulator & ln
						--set comment of (tracks t) to ""
					end repeat
				end tell
			end timeout
			EOT
		echo "done!"
	fi
}

copy_tracks() {
	echo "This feature will copy tracks to specified location in order of genre >> artist >> album >> track"

	path=""

	while [ ! -d "$path" ]
	do
		echo -n "Enter path to copy to: "

		read path
	done

	echo "Copying tracks, this will take a long time.."

	tracks=`osascript -e "
		tell application \"iTunes\"
			count of tracks
		end tell"`

	echo $tracks;

	for (( c=1; c<=$tracks; c++ ))
	do
		genre=`osascript -e "
			tell application \"iTunes\"
				get genre of track $c
			end tell"`
		artist=`osascript -e "
			tell application \"iTunes\"
				get artist of track $c
			end tell"`
		album=`osascript -e "
			tell application \"iTunes\"
				get album of track $c
			end tell"`
		location=`osascript -e "
			tell application \"iTunes\"
				get location of track $c
			end tell"`

		cd "$path"

		genre_filename=`echo "$genre" | sed 's/\\//|/g'`
	
		mkdir "$genre_filename" &> /dev/null

		cd "$genre_filename"
		
		artist_filename=`echo "$artist" | sed 's/\\//|/g'`
	
		mkdir "$artist_filename" &> /dev/null
		
		cd "$artist_filename"
		
		album_filename=`echo "$album" | sed 's/\\//|/g'`
		
		mkdir "$album_filename" &> /dev/null

		cd "$album_filename"

		trackpath=`echo "$location" | sed 's/.*:Users/:Users/;s/:/\//g'`

		filename=`echo "$trackpath" | sed 's/.*\\/\(.*\.mp3\)$/\1/;s/\\//|/g'`

		#if [ ! -f "$filename" ] 
		#then
			#cp "$trackpath" "$filename"
		#fi

		echo -n -e "\r$c of $tracks - $trackpath"
	done

	echo

	echo "All done!"
}

while :
do
	cat << !
------
1. Library Overview
2. Convert AAC
3. Convert WAV
4. Delete AAC
5. Delete WAV
6. Strip Comments
7. Copy tracks
8. Exit
------
!
	echo -n "option: "

	read choice

	case $choice in
		1) library_overview ;;
		2) convert_aac ;;
		3) convert_wav ;;
		4) delete_aac ;;
		5) delete_wav ;;
		6) stip_comments ;;
		7) copy_tracks ;;
		8) exit ;;
		*) sleep 1 ;;
	esac
done
