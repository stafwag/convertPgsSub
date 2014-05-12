#!/bin/bash

#
#  convertPgsSub.sh
#
#  Copyright (C) 2014  Staf Wagemakers Belgie/Belgium
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
# 


#
# basic settings
#


BDSup2SubJar="/home/staf/scripts/jar/BDSup2Sub.jar"

ScriptName="`basename $0`"
TmpDir="/home/staf/tmp"

Version="1.0.0preXXX"

cat <<-_END_OF_HEADER_ >&2
	${ScriptName}  version ${Version}
	Copyright (C) 2014  Staf Wagemakers Belgie/Belgium
	----------------------------------------------------------------------
_END_OF_HEADER_

#
# Usage
#

usage() {
	cat <<-_END_OF_HELP_ >&2
		Usage: ${ScriptName} -i inputFile.mkv -o outputFile.mkv [OPTION]

		Options:

		 -i	inputFile
		 -o	outputFile
		 -v	enable verbosity
		 -d	delete temporary files

	_END_OF_HELP_
	return 0
}

#
# getFullPathDir
#

getFullPathDir() {


	currentDir=`pwd`

	myDir=`dirname $1`

	cd "$myDir"

	if [ $? != "0" ]; then

		echo "$myDir"

		return 1


	fi

	myDir=`pwd`

	cd "$currentDir"

	echo $myDir


	return 0

}

#
# Get the options
#

outputFile=""
inputFile=""
Verbose=""
DeleteIt=""

while getopts ":o:i:vdh" opt; do

  	case $opt in

    	o)
		outputFile="$OPTARG"
		;;
    	i)
		inputFile="$OPTARG"
		;;

	v)
		Verbose=1
		;;

	d)
		DeleteIt=1
		;;

    	h)
      		usage
		exit 0
      		;;

    	\?)
      		usage
		exit 0
      		;;

  esac


done

#
# set TmpDir
#

if [ "$Verbose" ]; then


	echo "DEBUG: tmpDir= $TmpDir" >&2

fi

if [ ! -d $TmpDir ]; then

	echo "Sorry TmpDir: $TmpDir is not a directory" >&2
	exit 1

fi

TmpDir="/home/staf/tmp/`basename $ScriptName`"

if [ ! -d $TmpDir ]; then

	echo >&2
	echo "Creating $TmpDir:" >&2
	echo >&2


	mkdir $TmpDir

	if [ $? != "0" ]; then

		echo >&2
		echo "Sorry, failed to create $TmpDir" >&2
		echo >&2


	fi 


fi

#
# settings
#

if [ "$Verbose" ]; then


echo >&2
echo "outputFile=\"$outputFile\"" >&2
echo "inputFile=\"$inputFile\"" >&2
echo "verbose=\"$Verbose\"" >&2
echo "DeleteIt=\"$DeleteIt\"" >&2
echo >&2

fi

#
# outputFile and inputFile required
#

if [ -z "$inputFile" ] || [ -z "$outputFile" ]; then   

	echo >&2
	echo "Sorry, inputFile and outputFile are required" >&2
	echo >&2

	usage 
	exit 1

fi

#
# set the outputFile to the fullpathdir
#


outputDir=`getFullPathDir $outputFile`

outputBaseFileName=`basename $outputFile`
outputFile="${outputDir}/${outputBaseFileName}"

if [ "$Verbose" ]; then

echo >&2
echo "DEBUG: outputDir=\"$outputDir\"" >&2
echo "DEBUG: outputFile=\"$outputFile\"" >&2
echo >&2

fi

#
# set the inputFile to the fullpathdir
#

inputDir=`getFullPathDir $inputFile`

inputBaseFileName=`basename $inputFile`
inputFile="${inputDir}/${inputBaseFileName}"

if [ "$Verbose" ]; then

echo >&2
echo "DEBUG: inputDir=\"$inputDir\"" >&2
echo "DEBUG: inputFile=\"$inputFile\"" >&2
echo >&2

fi

#
# no input, dont exec
#

if [ ! -r "$inputFile" ]; then

	echo >&2
	echo "Sorry, failed to read $inputFile" >&2
	echo >&2
	exit 1

fi

#
# Create the VideoTmpDir or die
#

VideoTmpDir="$TmpDir/`basename $inputFile`/"

if [ ! -d "$VideoTmpDir" ]; then

	echo >&2
	echo "Creating:  $VideoTmpDir" >&2
	echo >&2

	mkdir -p $VideoTmpDir

	if [ $? != "0" ]; then

		echo >&2
		echo "Sorry, failed to create $VideoTmpDir" >&2
		echo >&2
		exit 1

	fi

fi

cd $VideoTmpDir

if [ $? != "0" ]; then

	echo >&2
	echo "Sorry, cd $VideoTmpDir failed" >&2
	echo >&2

	exit 1

fi

#
# Create the video index file or die
#

IndexFile="$VideoTmpDir/index"

> $IndexFile > /dev/null

if [ $? != "0" ]; then

	echo >&2
	echo "Sorry failed to create the IndexFile: $IndexFile" >&2
	echo >&2

	exit 1

fi

echo >&2
echo "Creating indexFile: $IndexFile: running  mkvmerge -I $inputFile > $IndexFile" >&2
echo $IndexFile >&2

mkvmerge -I  $inputFile > $IndexFile

if [ $? != "0" ]; then

	echo >&2
	echo "Sorry, mkvmerge -I $inputFile failed" >&2
	echo >&2
	exit 1

fi

#
# check if there are pgs subtitles
#

cat $IndexFile | grep "PGS" > /dev/null

if [ $? != "0" ]; then

	echo >&2
	echo "No, PGS subtitles found" >&2
	echo >&2
	exit 1


fi

#
# Get the videoTracks from the index
#

videoTracks=`cat $IndexFile | sed "1d" | head -n -1 | grep "^Track" |  sed -e 's/.*ID \(.*:\) \(.*\) (\(.*\)).*language:\(...\) .*$/\1\2\.\4.\3/' | sed -e 's/^\(.*\.\).*\(...\)$/\1\2/' | tr "A-Z" "a-z" | sed -e 's/^\(.*\)\:\(.*\)\.\(.*\)$/\1\:\2\.\1_\3/' | tr "\n" " "`

#
# extractIt
#

echo "Executing mkvextract tracks $inputFile $videoTracks" >&2

if [ "$Verbose" ]; then

	echo >&2
	echo "DEBUG: videoTracks: \"$videoTracks\"" >&2
	echo "DEBUG: langTracks: \"$langTracks\"" >&2
	echo >&2

fi

mkvextract tracks $inputFile $videoTracks

if [ $? != "0" ]; then

	echo >&2
	echo "Sorry, mkvextract tracks $inputFile $videoTracks failed" >&2
	echo >&2
	exit 1


fi

mergeTracks=""
extraSubFiles=""

#
# convert the pgs subtitles
#

for track in $videoTracks; do

	echo >&2
	echo "t: $track" >&2
	echo >&2

	trackFile=`echo $track | cut -f2 -d ':'`

	echo $track | grep -E "pgs$"

	if [ $? = "0" ]; then

		outBasename=`echo $trackFile | cut -f 1 -d '.'`
		outSub="${outBasename}.sub"

		java -jar $BDSup2SubJar  $trackFile -o $trackFile.sub

		if [ $? != "0" ]; then

			echo >&2
			echo "Sorry, subtitle convertion failed" >&2
			echo >&2

			exit 1


		fi

		extraSubFiles="${extraSubFiles} ${trackFile}.sub ${trackFile}.idx"

		trackFile="${trackFile}.idx"


	fi

	mergeTracks="$mergeTracks $trackFile"

done 

#
# set the lang for each track
#

langTracks=`echo $mergeTracks | tr " " "\n" | sed '/^$/d' | sed -e 's/^\(\([^.]*\)\.\([^.]*\)\..*\)$/--language 0:\3 \1/' | tr "\n" " "`

if [ "$Verbose" ]; then

	echo >&2
	echo "DEBUG: langTracks=\"$langTracks\"" >&2
	echo "DEBUG: mergeTracks=\"$mergeTracks\"" >&2
	echo "DEBUG: videoTracks=\"$videoTracks\"" >&2
	echo >&2

fi

#
# merge them
#

mkvmerge -o ${outputFile} $langTracks

if [ $? != "0" ]; then

	echo >&2
	echo "Sorry, mkvmerge failed \"mkvmerge -o ${outputFile}_lang $langTracks\"" >&2
	echo >&2

	exit 1

fi

if [ "$Verbose" ]; then

	echo >&2
	echo "DEBUG \"mkvmerge -o ${outputFile}_lang $langTracks\" executed"
	echo >&2

fi

#
# delete the temporary files
#

if [ "$DeleteIt" ]; then

	if [ "Verbose" ]; then


		echo "DEBUG: videoTracks: \"$videoTracks\""
		echo "DEBUG: extraSubFiles : \"$extraSubFiles\""
		echo "DEBUG: indexFile: \"$indexFile\""


	fi


	echo "Removing video tracks:"

	for file in $videoTracks; do

		fileToDel=`echo $file | cut -f2- -d  ':'`

		if [ -f "$fileToDel" ]; then

		echo "deleting:  \"$fileToDel\""

			rm "$fileToDel"

			if [ $? != "0" ]; then

				echo "Sorry failed to delete \"$fileToDel\""
				exit 1

			fi


		fi

	done

	echo "Removing extra subFiles"

	for fileToDel in $extraSubFiles; do

		if [ -f "$fileToDel" ]; then

			echo "deleting:  \"$fileToDel\""

			rm "$fileToDel"

		fi

	done

	echo "Removing indexFile"

	rm $IndexFile

fi
