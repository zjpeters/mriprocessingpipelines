#!/usr/bin/env bash

helpRequest() {
    [ "$#" -ne "2" ] || [ "$1" = '-h' ] || [ "$1" = '-help' ]
}
if helpRequest "$@"; then
    echo "Usage: `basename $0` {imageLocation} {derivatives}"
    echo "Performs preprocessing on diffusion weighted imaging data."
    echo "rawdata is the folder containing subject folders and participants.tsv"
    echo "derivatives is the folder where data is output to."
    echo "outputFilename is what you want to name your file"
    exit 0;
fi
scriptPath=`dirname $0`
scriptPath=`readlink -f $scriptPath`

#input files
    imageName=$(basename ${imageLocation})
    subID=${imageName%%_*}
    dwiImage[2]="${imageLocation//.nii.gz/_dwi.nii.gz[2]}"


###
# 
###
outputDir="${derivatives}/${subID}"
if [ ! -d "${outputDir}" ]; then 
    mkdir "${outputDir}"
fi

outputBaseName="${outputDir}/${imageName%%.nii.gz}"
# output files
    mask_thr24000="${outputBaseName}"_dwi__mask_thr24000.nii.gz
    
3dcalc -a "${dwiImage[2]}" \
     -expr 'ispositive(a-24000)' \
      -prefix "${mask_thr24000}"
