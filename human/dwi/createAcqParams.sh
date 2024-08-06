#!/bin/bash
#Requirements: FSL
if [ $# != 2 ] ; then
  echo "Usage: `basename $0` {rawdata} {derivatives} {participantsTsv}"
  echo "Function will generate acqparams.txt files for all subjects"
  echo "contained in rawdata/participants.tsv."
  echo "If no participants.tsv file is given, script will assume"
  echo "there is a file named 'participants.tsv' inside rawdata"
  exit 0;
fi

rawdata=$1
derivatives=$2
participantsTsv=${3-${rawdata}/participants.tsv}

# subject=/Users/zjpeters/biomarkersOfECT/rawdata/sub-P001/session01/dti
# topup --imain=$subject/all_b0_z-1.nii.gz --datain=$subject/acqparams.txt --out=$subject/topupresults_column2 --config=$subject/b02b0_7t.cnf --fout=$subject/topupfield_column2 --iout=$subject/unwarpedimages_column2
while read participant_id; do
  [ "$participant_id" == participant_id ] && continue;  # skips the header
  while read session_id; do
    [ "$session_id" == session_id ] && continue;  # skips the header
    # set up input images need to go through and fix the naming for "DTI_-_Rev"
    dtiFor=${rawdata}/${participant_id}/${session_id}/dti/${participant_id}_${session_id}_Ax_DTI.nii.gz
    dtiRev=${rawdata}/${participant_id}/${session_id}/dti/${participant_id}_${session_id}_Ax_DTI_-_Rev.nii.gz
    bvals=$(cat ${rawdata}/${participant_id}/${session_id}/dti/${participant_id}_${session_id}_Ax_DTI.bval)
    # output files
    croppedDti=${rawdata}/${participant_id}/${session_id}/dti/${participant_id}_${session_id}_Ax_DTI_cropped.nii.gz
    b0For=${rawdata}/${participant_id}/${session_id}/dti/${participant_id}_${session_id}_Ax_DTI_b0.nii.gz
    b0Rev=${rawdata}/${participant_id}/${session_id}/dti/${participant_id}_${session_id}_Ax_DTI_Rev_b0.nii.gz
    all_b0=${rawdata}/${participant_id}/${session_id}/dti/${participant_id}_${session_id}_Ax_DTI_all_b0.nii.gz
    xDim=$(fslval $dtiFor dim1)
    yDim=$(fslval $dtiFor dim2)
    zDim=$(fslval $dtiFor dim3)
    tDim=$(fslval $dtiFor dim4)

    nb0s=0
    for i in $bvals; do
      if [ $i == 0 ]; then
        ((nb0s++))
      fi
    done
    # need to first check if image has even number of slices in each direction
    if [ $((xDim%2)) != 0 ]; then
      ((xDim--))
    fi
    if [ $((yDim%2)) != 0 ]; then
      ((yDim--))
    fi
    if [ $((zDim%2)) != 0 ]; then
      ((zDim--))
    fi
    # shouldn't need an if statement, since it's a good idea to make sure they all go through the same process anyway
#    if [ $((xDim%2)) != 0 ] || [ $((yDim%2)) != 0 ] || [ $((zDim%2)) != 0 ]; then
    fslroi $dtiFor $croppedDti 0 $xDim 0 $yDim 0 $zDim 0 $tDim
    fslroi $croppedDti $b0For 0 $xDim 0 $yDim 0 $zDim 0 $nb0s
    # we only need the b0 of images from the reverse image, don't need to crop twice
    fslroi $dtiRev $b0Rev 0 $xDim 0 $yDim 0 $zDim 0 $nb0s
    # create the b0
    fslmerge -t $all_b0 $b0For $b0Rev
    # collect the phase encoding direction and total readout time from json
    # will need to adjust for whether the key is PhaseEncodingDirection, PhaseEncodingAxis, or InPlanePhaseEncodingDirectionDICOM
    #ped=$(jq '.PhaseEncodingAxis' ${dtiFor//.nii.gz/.json})
    ped=$(jq '.InPlanePhaseEncodingDirectionDICOM' ${dtiFor//.nii.gz/.json})
    echo "Phase encoding direction: $ped"
    trt=$(jq '.TotalReadoutTime' ${dtiFor//.nii.gz/.json})
    echo "Total readout time: $trt"
    # pedRev=$(jq '.PhaseEncodingDirection' ${dtiRev//.nii.gz/.json})
    # trtRev=$(jq '.TotalReadoutTime' ${dtiRev//.nii.gz/.json})

    echo "Creating new acqparams file for $participant_id $session_id"
    acqparams=${rawdata}/${participant_id}/${session_id}/dti/acqparams.txt
    if [ ! -f $acqparams ]; then
      touch $acqparams
    else
      rm $acqparams
      touch $acqparams
    fi
    # will now write acqparams files that have one row for each b0
    # if [ $ped == "\"j\"" ]; then
    #   for i in $(seq 1 $nb0s); do
    #     printf "0 1 0 $trt\n" >> $acqparams
    #   done
    #   for i in $(seq 1 $nb0s); do
    #     printf -- "0 -1 0 $trt\n" >> $acqparams
    #   done
    # elif [ $ped == "\"j-\"" ]; then
    #   for i in $(seq 1 $nb0s); do
    #     printf "0 -1 0 $trt\n" >> $acqparams
    #   done
    #   for i in $(seq 1 $nb0s); do
    #     printf -- "0 1 0 $trt\n" >> $acqparams
    #   done
    # elif [ $ped == "\"i\"" ]; then
    #   for i in $(seq 1 $nb0s); do
    #     printf "1 0 0 $trt\n" >> $acqparams
    #   done
    #   for i in $(seq 1 $nb0s); do
    #     printf -- "-1 0 0 $trt\n" >> $acqparams
    #   done
    # elif [ $ped == "\"i-\"" ]; then
    #   for i in $(seq 1 $nb0s); do
    #     printf "-1 0 0 $trt\n" >> $acqparams
    #   done
    #   for i in $(seq 1 $nb0s); do
    #     printf -- "1 0 0 $trt\n" >> $acqparams
    #   done
    # fi
    if [ $ped == "\"COL\"" ]; then
      for i in $(seq 1 $nb0s); do
        printf "0 1 0 $trt\n" >> $acqparams
      done
      for i in $(seq 1 $nb0s); do
        printf -- "0 -1 0 $trt\n" >> $acqparams
      done
    elif [ $ped == "\"ROW\"" ]; then
      for i in $(seq 1 $nb0s); do
        printf "1 0 0 $trt\n" >> $acqparams
      done
      for i in $(seq 1 $nb0s); do
        printf -- "-1 0 0 $trt\n" >> $acqparams
      done
    fi
    cat $acqParams
  done < ${rawdata}/${participant_id}/sessions.tsv
done < ${participantsTsv}
