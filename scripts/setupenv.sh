#!/bin/zsh

# This is used as the first run phase in cryptex aggregate targets in order to gather environment information for the following steps
source $SCRIPT_INPUT_FILE_0

if ! command -v cryptexctl &> /dev/null
then
    echo "error: cryptexctl could not be found; make sure your .zshrc includes the directory where cryptexctl can be found in PATH"
    exit 1
fi

CRYPTEXCTL_PATH=`which cryptexctl`
echo "export CRYPTEXCTL_PATH=${CRYPTEXCTL_PATH}" > $SCRIPT_OUTPUT_FILE_0

if [ -z "$CRYPTEXCTL_UDID" ]; then
    echo "error: CRYPTEXCTL_UDID environment variable missing; make sure your .zshrc exports CRYPTEXCTL_UDID with the UDID of your SRD"
    exit 1
fi
echo "export CRYPTEXCTL_UDID=${CRYPTEXCTL_UDID}" >> $SCRIPT_OUTPUT_FILE_0
