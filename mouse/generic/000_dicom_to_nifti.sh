#!/bin/bash
#Requirements: FSL
sourcedata=/home/zjpeters/rdss_tnj/creativity/sourcedata
rawdata=/home/zjpeters/rdss_tnj/creativity/rawdata
derivatives=/home/zjpeters/rdss_tnj/creativity/derivatives

for folder in $sourcedata/sub-*; do
  echo $folder
  if [ -d $folder ]; then
    dcm2niix -d 9 -b y -z y -i y -f %n_ses-%t_%d -o $rawdata $folder
  fi
done

./organize_rawdata_folder.sh

