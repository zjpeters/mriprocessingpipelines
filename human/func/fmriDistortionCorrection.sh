#!/bin/bash
rawdata=/home/hmzipf/rdss_tnj/biomarkersOfECT/rawdata
derivatives=/home/hmzipf/rdss_tnj/biomarkersOfECT/derivatives
sourcedata=/home/hmzipf/rdss_tnj/biomarkersOfECT/sourcedata

while read participant_id; do
  [ "$participant_id" == participant_id ] && continue;  # skips the header
  while read session_id; do
    [ "$session_id" == session_id ] && continue;
    #echo "Now running nonlinear distortion correction on ${participant_id} ${session_id}"
    #input files
    fMRIscan=${rawdata}/${participant_id}/${session_id}/func/${participant_id}_${session_id}_fMRI_deoblique.nii.gz
    t2wImage=${rawdata}/${participant_id}/${session_id}/t2/${participant_id}_${session_id}_Sag_CUBE_T2.nii.gz
    # dwiRev=${rawdata}/${participant_id}/${session_id}/dwi/${participant_id}_${session_id}_Ax_dwi_-_Rev.nii.gz
    bvals=$(cat ${rawdata}/${participant_id}/${session_id}/func/${participant_id}_${session_id}_fMRI_.bval)
    # output files
    croppedfMRI=${rawdata}/${participant_id}/${session_id}/func/distortionCorrection/${participant_id}_${session_id}_fMRI_cropped.nii.gz
    b0=${rawdata}/${participant_id}/${session_id}/func/${participant_id}_${session_id}_fMRI_
    t2wResamp=${derivatives}/${participant_id}/${participant_id}_${session_id}_Sag_CUBE_T2_resamp2fMRI.nii.gz
    t2wInm=${derivatives}/${participant_id}/${participant_id}_${session_id}_Sag_CUBE_T2_resamp2fMRI_inm.nii.gz
    t2wDenoised=${derivatives}/${participant_id}/${participant_id}_${session_id}_Sag_CUBE_T2_resamp2fMRI_denoised.nii.gz
    b0Nonlin=${derivatives}/${participant_id}/${participant_id}_${session_id}_fMRI_b0_nonlin
    fMRINonlin=${derivatives}/func/distortionCorrection/${participant_id}_${session_id}_fMRI_nonlin
    if [ ! -d ${derivatives}/${participant_id} ]; then
        mkdir -p ${derivatives}/${participant_id}
    fi
    b0Mean=${derivatives}/${participant_id}/${participant_id}_${session_id}_fMRI_b0mean.nii.gz
    b0Denoised=${derivatives}/${participant_id}/${participant_id}_${session_id}_fMRI_b0mean_denoised.nii.gz

    if [ ! -f $fMRIscan ]; then
      echo "$fMRIscan does not exist"
      continue
    elif [ -f ${fMRINonlin}.nii.gz ]; then
      echo "processing has already been run for $participant_id $session_id"
      continue
    else
        echo "Beginning processing of $participant_id $session_id"
        fslmaths $fMRIscan -Tmean $b0Mean
        3dresample -master $fMRIscan -input ${t2wImage} -prefix ${t2wResamp}
        meanIntensity=$(fslstats $b0Mean -m)
        fslmaths $t2wResamp -inm $meanIntensity $t2wInm
        # not including mask in denoising since it hasn't been generated yet
        DenoiseImage -d 3 -n Rician -s 1 -p 1 -r 2 -v 1 -i ${t2wResamp} -o [${t2wDenoised},${t2wDenoised//denoised/noise}]
        DenoiseImage -d 3 -n Rician -s 1 -p 1 -r 2 -v 1 -i ${b0Mean} -o [${b0Denoised},${b0Denoised//denoised/noise}]
        t2wBrain=${derivatives}/func/distortionCorrection/${participant_id}_${session_id}_Sag_CUBE_T2_resamp2fMRI_denoised_fMRI_brain
        bet ${t2wDenoised} $t2wBrain -m
        echo "Finished mask"
        # run antsRegistration on data
        antsRegistration --dimensionality 3 --output ${b0Nonlin} --initial-moving-transform [${t2wBrain}.nii.gz,${b0Denoised},1] -x ${t2wBrain}_mask.nii.gz \
        --transform Rigid[0.1] --metric Mattes[${t2wBrain}.nii.gz,${b0Denoised},1,32,Regular,0.25] --convergence [2000x2000x2000x2000x2000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
        --transform Affine[0.1] --metric Mattes[${t2wBrain}.nii.gz,${b0Denoised},1,32,Regular,0.25] --convergence [1000x1000x1000x1000x1000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
        --transform SyN[0.175,2,0] --metric CC[${t2wBrain}.nii.gz,${b0Denoised},1,4] --convergence [1000x1000x1000x1000x1000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
        --use-histogram-matching 1 --verbose 1 --random-seed 13983981 --winsorize-image-intensities [0.005,0.995] --write-composite-transform 1

        antsApplyTransforms -d 3 -n BSpline[3] -i ${b0Denoised} -o ${b0Nonlin}.nii.gz -t ${b0Nonlin}Composite.h5 -r ${t2wBrain}.nii.gz -v
        antsApplyTransforms -d 3 -e 3 -n BSpline[3] -i ${fMRIscan} -o ${fMRINonlin}.nii.gz -t ${b0Nonlin}Composite.h5 -r ${t2wBrain}.nii.gz
    fi
    done < ${rawdata}/${participant_id}/sessions.tsv
done < ${rawdata}/participants.tsv