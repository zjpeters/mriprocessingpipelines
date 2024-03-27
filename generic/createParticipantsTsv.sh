#!/bin/bash
if [ $# != 1 ] ; then
  echo "Usage: `basename $0` {rawdata}"
  echo "Create a basic participants.tsv and accompanying sessions.tsv files"
  exit 0;
fi

rawdata="$(realpath "${1}")"
if [ -f "${rawdata}"/participants.tsv ]; then
    echo "participants.tsv already exists!"
    exit 1
else
    touch "${rawdata}"/participants.tsv
    echo -e "participant_id" > "${rawdata}"/participants.tsv
    for subject in "${rawdata}"/sub-*; do
        subID="$(basename "${subject}")"
        echo -e "$subID" >> "${rawdata}"/participants.tsv
        touch "${subject}"/sessions.tsv
        echo -e "session_id" > "${subject}"/sessions.tsv
        for session in ${subject}/ses-*; do
            sesID="$(basename "${session}")"
            echo -e "$sesID" >> "${subject}"/sessions.tsv
        done
    done
fi
