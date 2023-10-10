#!/bin/bash
rawdata=/home/zjpeters/rdss_tnj/twiceExceptional/rawdata
derivatives=/home/zjpeters/rdss_tnj/twiceExceptional/derivatives
sourcedata=/home/zjpeters/rdss_tnj/twiceExceptional/sourcedata

# since dicom_to_nifti outputs directly into rawdata, should be lots of niftis
# assumes that there will be no underscores within the session ID
# for SWI, it seems all datasets have e{1..9}.nii.gz files, along with imaginary/real versions
# therefore use e1 to identify unique session

for actImage in $rawdata/*T1.nii.gz; do
	filename=$(basename $actImage)
	subID=${filename%_ses*}
	sesID=${filename#*${subID}_}
	sesID=${sesID%%_*}
	echo $subID $sesID
	if [ ! -d $rawdata/$subID/$sesID/anat ]; then
		mkdir -p $rawdata/$subID/$sesID/anat
	fi
	mv $rawdata/${subID}_${sesID}*T1*  $rawdata/$subID/$sesID/anat
	mv $rawdata/${subID}_${sesID}*T2*  $rawdata/$subID/$sesID/anat
done


for actImage in $rawdata/*DTI_32_DIR.nii.gz; do
	filename=$(basename $actImage)
	subID=${filename%_ses*}
	sesID=${filename#*${subID}_}
	sesID=${sesID%%_*}
	echo $subID $sesID
	if [ ! -d $rawdata/$subID/$sesID/dwi ]; then
		mkdir -p $rawdata/$subID/$sesID/dwi
	fi
	mv $rawdata/${subID}_${sesID}*DTI*  $rawdata/$subID/$sesID/dwi
done


for actImage in $rawdata/*fMRI_REST_Run_1.nii.gz; do
	filename=$(basename $actImage)
	subID=${filename%_ses*}
	sesID=${filename#*${subID}_}
	sesID=${sesID%%_*}
	echo $subID $sesID
	if [ ! -d $rawdata/$subID/$sesID/func ]; then
		mkdir -p $rawdata/$subID/$sesID/func
	fi
	mv $rawdata/${subID}_${sesID}*fMRI*  $rawdata/$subID/$sesID/func
done

for actImage in $rawdata/*.nii.gz; do
	filename=$(basename $actImage)
	subID=${filename%_ses*}
	sesID=${filename#*${subID}_}
	sesID=${sesID%%_*}
	echo $subID $sesID
	if [ ! -d $rawdata/$subID/$sesID/other ]; then
		mkdir -p $rawdata/$subID/$sesID/other
	fi
	mv ${actImage%%.nii.gz}*  $rawdata/$subID/$sesID/other
done