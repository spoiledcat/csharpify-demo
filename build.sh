#!/bin/bash -eu

{ set +x; } 2>/dev/null
SOURCE=$0
DIR="$( pwd )"

CONFIGURATION=Debug
PRESET=
ZIP=
ARGSONLY=0
ARGS=

while (( "$#" )); do
	if [[ x"$ARGSONLY" == x"1" ]]; then
		ARGS="${ARGS} $1"
		shift
		continue
	fi

	case "$1" in
		-d|--debug)
			CONFIGURATION="Debug"
		;;
		-r|--release)
			CONFIGURATION="Release"
		;;
		-c|--configuration)
			shift
			CONFIGURATION=$1
		;;
		pc|--coreclr)
			PRESET=coreclr
		;;
		pm|--mono)
			PRESET=mono
		;;
		pn|--nativeaot)
			PRESET=nativeaot
		;;
		-z)
		shift
		ZIP=$1
		;;
		-v|--verbose)
			ARGS="${ARGS} --verbose"
		;;
		--args)
			ARGSONLY=1
		;;
		--trace)
		 { set -x; } 2>/dev/null
		;;
		*)
		ARGS="${ARGS} $1"
		;;
	esac
	shift
done

cmake --preset $PRESET -DCSHARPIFY_ZIP=$ZIP
cmake --build --preset $PRESET
