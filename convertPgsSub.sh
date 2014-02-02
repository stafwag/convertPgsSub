#!/bin/bash

BDSup2SubJar="/home/staf/scripts/jar/BDSup2Sub.jar"

ScriptName="`basename $0`"
TmpDir="/home/staf/tmp/`basename $ScriptName`"


echo "DEBUG: tmpDir= $TmpDir"

usage() {

	echo "Usage: $ScriptName inputFile.mkv outputFile"
	exit 1

}

if [ "$#" != "2" ]; then

	usage

fi

inputFile=$1
outputFile=$2

if [ ! -r "$inputFile" ]; then

	echo "Sorry, failed to read $inputFile"
	exit 1

fi

VideoTmpDir="$TmpDir/`basename $inputFile`/"

if [ ! -d "$VideoTmpDir" ]; then

	echo "Creating:  $VideoTmpDir"

	mkdir -p $VideoTmpDir

	if [ $? != "0" ]; then

		echo "Sorry, failed to create $VideoTmpDir"
		exit 1

	fi

fi

IndexFile="$VideoTmpDir/index"

rm $IndexFile > /dev/null

echo "Creating indexFile: $IndexFile: running  mkvmerge -I $inputFile > $IndexFile"
echo $IndexFile

mkvmerge -I  $inputFile > $IndexFile

if [ $? -ne  0 ]; then

	echo "Sorry, mkvmerge -I $inputFile failed"
	exit 1

fi


cat $IndexFile | grep "PGS" > /dev/null

if [ $? != "0" ]; then

	echo "No, PGS subtitles found"
	exit 1


fi

# videoTracks=`cat $IndexFile | sed "1d" | head -n -1 | grep "^Track" |  sed -e 's/.*ID \(.*:\) \(.*\) (\(.*\))$/\1\2/' | sed -e 's/^\(.*\.\).*\(...\)$/\1\2/' | tr "\n" " "`

# videoTracks=`cat $IndexFile | sed "1d" | head -n -1 | grep "^Track" |  sed -e 's/.*ID \(.*:\) \(.*\) (\(.*\))$/\1\2\.\3/' | sed -e 's/^\(.*\.\).*\(...\)$/\1\2/' | tr "A-Z" "a-z" | tr  "\n" " "`
# videoTracks=`cat $IndexFile | sed "1d" | head -n -1 | grep "^Track" |  sed -e 's/.*ID \(.*:\) \(.*\) (\(.*\))$/\1\2\.\3/' | sed -e 's/^\(.*\.\).*\(...\)$/\1\2/' | tr "A-Z" "a-z" | sed -e 's/^\(.*\)\:\(.*\)\.\(.*\)$/\1\:\2\.\1_\3/' | tr "\n" " "`
videoTracks=`cat $IndexFile | sed "1d" | head -n -1 | grep "^Track" |  sed -e 's/.*ID \(.*:\) \(.*\) (\(.*\)).*language:\(...\) .*$/\1\2\.\4.\3/' | sed -e 's/^\(.*\.\).*\(...\)$/\1\2/' | tr "A-Z" "a-z" | sed -e 's/^\(.*\)\:\(.*\)\.\(.*\)$/\1\:\2\.\1_\3/' | tr "\n" " "`

echo "Executing mkvextract tracks $inputFile $videoTracks"

echo "DEBUG: videoTracks: \"$videoTracks\""

# langTracks=`echo $videoTracks | tr " " "\n" | sed -e 's/^\(.*:\).*\.\(.*\)\..*$/--language \1\2/' | tr "\n" " "`
# langTracks=`echo $videoTracks | tr " " "\n" | sed '/^$/d' | sed -e 's/^\(.*:\)\(.*\)\.\(.*\)\.\(.*\)/--language 0:\3 \2.\3.\4/' | tr "\n" " "`

echo "DEBUG: langTracks: \"$langTracks\""

mkvextract tracks $inputFile $videoTracks

if [ $? != "0" ]; then

	echo "Sorry, mkvextract tracks $inputFile $videoTracks failed"
	exit 1


fi


mergeTracks=""

for track in $videoTracks; do

	echo "t: $track"

	trackFile=`echo $track | cut -f2 -d ':'`

	echo $track | grep -E "pgs$"

	if [ $? = "0" ]; then

		outBasename=`echo $trackFile | cut -f 1 -d '.'`
		outSub="${outBasename}.sub"

		java -jar $BDSup2SubJar  $trackFile -o $trackFile.sub

		if [ $? != "0" ]; then

			echo "Sorry, subtitle convertion failed"
			exit 1


		fi

		trackFile="${trackFile}.idx"


	fi

	mergeTracks="$mergeTracks $trackFile"

done 

# echo "Running mkvmerge -o $outputFile $mergeTracks"
# 
# mkvmerge -o $outputFile $mergeTracks
# 
# if [ $? != "0" ]; then
# 
	# echo "Sorry, mkvmerge failed"
	# exit 1
# 
# fi

langTracks=`echo $mergeTracks | tr " " "\n" | sed '/^$/d' | sed -e 's/^\(\([^.]*\)\.\([^.]*\)\..*\)$/--language 0:\3 \1/' | tr "\n" " "`
echo "DEBUG: langTracks=\"$langTracks\""
echo "DEBUG: mergeTracks=\"$mergeTracks\""
echo "DEBUG: videoTracks=\"$videoTracks\""

mkvmerge -o ${outputFile} $langTracks

if [ $? != "0" ]; then

	echo "Sorry, mkvmerge failed \"mkvmerge -o ${outputFile}_lang $langTracks\""
	exit 1

fi

echo "DEBUG \"mkvmerge -o ${outputFile}_lang $langTracks\" executed"
