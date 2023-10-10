#!/bin/bash
rawdata=/media/zjpeters/Samsung_T5/willSWI/rawdata
derivatives=/media/zjpeters/Samsung_T5/willSWI/derivatives
sourcedata=/media/zjpeters/Samsung_T5/willSWI/sourcedata

while read participant_id; do
  [ "$participant_id" == participant_id ] && continue;  # skips the header
  while read session_id; do
    [ "$session_id" == session_id ] && continue;  # skips the header

    #input files
    dwiFor=${rawdata}/${participant_id}/${session_id}/dwi/${participant_id}_${session_id}_dwi.nii.gz
    t2wImage=${rawdata}/${participant_id}/${session_id}/anat/${participant_id}_${session_id}_anat-T2w.nii.gz
    # dwiRev=${rawdata}/${participant_id}/${session_id}/dwi/${participant_id}_${session_id}_Ax_dwi_-_Rev.nii.gz
    bvals=$(cat ${rawdata}/${participant_id}/${session_id}/dwi/${participant_id}_${session_id}_dwi.bval)

    # output files
    croppeddwi=${rawdata}/${participant_id}/${session_id}/dwi/${participant_id}_${session_id}_dwi_cropped.nii.gz
    b0For=${rawdata}/${participant_id}/${session_id}/dwi/${participant_id}_${session_id}_dwi_b0.nii.gz
    t2wResamp=${derivatives}/${participant_id}/${participant_id}_${session_id}_anat-T2w_resamp2dwi.nii.gz
    t2wInm=${derivatives}/${participant_id}/${participant_id}_${session_id}_anat-T2w_resamp2dwi_inm.nii.gz
    t2wDenoised=${derivatives}/${participant_id}/${participant_id}_${session_id}_anat-T2w_resamp2dwi_denoised.nii.gz
    b0Nonlin=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_b0_nonlin
    dwiNonlin=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_nonlin
    if [ ! -d ${derivatives}/${participant_id} ]; then
        mkdir -p ${derivatives}/${participant_id}
    fi
    b0Mean=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_b0_mean.nii.gz
    b0Denoised=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_b0_mean_denoised.nii.gz
    # b0Rev=${rawdata}/${participant_id}/${session_id}/dwi/${participant_id}_${session_id}_Ax_dwi_Rev_b0.nii.gz
    # all_b0=${rawdata}/${participant_id}/${session_id}/dwi/${participant_id}_${session_id}_Ax_dwi_all_b0.nii.gz
    xDim=$(fslval $dwiFor dim1)
    yDim=$(fslval $dwiFor dim2)
    zDim=$(fslval $dwiFor dim3)
    tDim=$(fslval $dwiFor dim4)

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
    fslroi $dwiFor $croppeddwi 0 $xDim 0 $yDim 0 $zDim 0 $tDim
    fslroi $croppeddwi $b0For 0 $xDim 0 $yDim 0 $zDim 0 $nb0s
    # # we only need the b0 of images from the reverse image, don't need to crop twice
    # fslroi $dwiRev $b0Rev 0 $xDim 0 $yDim 0 $zDim 0 $nb0s
    fslmaths $b0For -Tmean $b0Mean
    3dresample -master $dwiFor -input ${t2wImage} -prefix ${t2wResamp}
    meanIntensity=$(fslstats $b0Mean -m)
    fslmaths $t2wResamp -inm $meanIntensity $t2wInm
# not including mask in denoising since it hasn't been generated yet
    DenoiseImage -d 3 -n Rician -s 1 -p 1 -r 2 -v 1 -i ${t2wInm} -o [${t2wDenoised},${t2wDenoised//denoised/noise}]
    DenoiseImage -d 3 -n Rician -s 1 -p 1 -r 2 -v 1 -i ${b0Mean} -o [${b0Denoised},${b0Denoised//denoised/noise}]
    # run antsRegistration on data
    antsRegistration --dimensionality 3 --output ${b0Nonlin} --initial-moving-transform [${t2wDenoised},${b0Denoised},1] \
      --transform Rigid[0.1] --metric Mattes[${t2wDenoised},${b0Denoised},1,32,Regular,0.25] --convergence [2000x2000x2000x2000x2000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
      --transform Affine[0.1] --metric Mattes[${t2wDenoised},${b0Denoised},1,32,Regular,0.25] --convergence [1000x1000x1000x1000x1000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
      --transform SyN[0.15,2,0] --metric CC[${t2wDenoised},${b0Denoised},1,4] --convergence [1000x1000x1000x1000x1000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
      --use-histogram-matching 1 --verbose 1 --random-seed 13983981 --winsorize-image-intensities [0.005,0.995] --write-composite-transform 1
    
    antsApplyTransforms -d 3 -n BSpline[3] -i ${b0Denoised} -o ${b0Nonlin}.nii.gz -t ${b0Nonlin}Composite.h5 -r $t2wDenoised
    antsApplyTransforms -d 3 -e 3 -n BSpline[3] -i ${dwiFor} -o ${dwiNonlin}.nii.gz -t ${b0Nonlin}Composite.h5 -r $t2wDenoised
    bet ${b0Nonlin}.nii.gz ${b0Nonlin}_mask.nii.gz -A2 $t2wDenoised
    dtifit -k ${b0Nonlin}.nii.gz -m ${b0Nonlin}_mask.nii.gz -r ${rawdata}/${participant_id}/${session_id}/dwi/${participant_id}_${session_id}_dwi.bvec -b ${rawdata}/${participant_id}/${session_id}/dwi/${participant_id}_${session_id}_dwi.bval
    # antsApplyTransforms -d 3 -i sub-CBFBM41T1_ses-20230327100040_dwi_b0_mean.nii.gz -o sub-CBFBM41T1_ses-20230327100040_dwi_nonlin.nii.gz -t sub-CBFBM41T1_ses-20230327100040_dwi_b0_nonlinComposite.h5 -r sub-CBFBM41T1_ses-20230327100040_anat-T2w_resamp2dwi.nii.gz 
    done < ${rawdata}/${participant_id}/sessions.tsv
done < ${rawdata}/participants.tsv
