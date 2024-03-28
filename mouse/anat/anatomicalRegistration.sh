#!/bin/bash
rawdata=~/rdss_tnj/creativity/rawdata
derivatives=~/rdss_tnj/creativity/derivatives
sourcedata=~/rdss_tnj/creativity/sourcedata

#####################################################
# converting to anat registration script from DWI
#####################################################

while read participant_id; do
  [ "$participant_id" == participant_id ] && continue;  # skips the header
  while read session_id; do
    [ "$session_id" == session_id ] && continue;  # skips the header

    #input files
    dwiFor=${rawdata}/${participant_id}/dwi/${participant_id}_${session_id}_DTI-30_DIRECTIONS.nii.gz
    t2wImage=${rawdata}/${participant_id}/anat/${participant_id}_${session_id}_T2-PREP_3D_T2-B15.nii.gz
    # dwiRev=${rawdata}/${participant_id}/${session_id}/dwi/${participant_id}_${session_id}_Ax_dwi_-_Rev.nii.gz
    bvals=$(cat ${rawdata}/${participant_id}/dwi/${participant_id}_${session_id}_DTI-30_DIRECTIONS.bval)
  
    # output files
    croppeddwi=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_cropped.nii.gz
    b0For=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_b0.nii.gz
    t2wResamp=${derivatives}/${participant_id}/${participant_id}_${session_id}_anat-T2w_resamp2dwi.nii.gz
    t2wInm=${derivatives}/${participant_id}/${participant_id}_${session_id}_anat-T2w_resamp2dwi_inm.nii.gz
    t2wDenoised=${derivatives}/${participant_id}/${participant_id}_${session_id}_anat-T2w_resamp2dwi_denoised.nii.gz
    b0Nonlin=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_b0_nonlin
    dwiNonlin=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_nonlin
    if [ ! -d ${derivatives}/${participant_id} ]; then
        mkdir -p ${derivatives}/${participant_id}
    fi

      resampleDwi=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_resampled.nii.gz
      dtiFitOutput=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_nonlin_proc
      3dresample -dxyz 2 2 2 -input ${dwiFor} -prefix ${resampleDwi} 
      # shouldn't need an if statement, since it's a good idea to make sure they all go through the same process anyway
    #    if [ $((xDim%2)) != 0 ] || [ $((yDim%2)) != 0 ] || [ $((zDim%2)) != 0 ]; then
      fslroi $resampleDwi $croppeddwi 0 $xDim 0 $yDim 0 $zDim 0 $tDim
      fslroi $croppeddwi $b0For 0 $xDim 0 $yDim 0 $zDim 0 $nb0s
      # # we only need the b0 of images from the reverse image, don't need to crop twice
      # fslroi $dwiRev $b0Rev 0 $xDim 0 $yDim 0 $zDim 0 $nb0s
      fslmaths $b0For -Tmean $b0Mean
      3dresample -master $croppeddwi -input ${t2wImage} -prefix ${t2wResamp}
      meanIntensity=$(fslstats $b0Mean -m)
      fslmaths $t2wResamp -inm $meanIntensity $t2wInm
    # not including mask in denoising since it hasn't been generated yet
      DenoiseImage -d 3 -n Rician -s 1 -p 1 -r 2 -v 1 -i ${t2wInm} -o [${t2wDenoised},${t2wDenoised//denoised/noise}]
      DenoiseImage -d 3 -n Rician -s 1 -p 1 -r 2 -v 1 -i ${b0Mean} -o [${b0Denoised},${b0Denoised//denoised/noise}]
      t2wBrain=${derivatives}/${participant_id}/${participant_id}_${session_id}_anat-T2w_resamp2dwi_denoised_brain
      bet ${t2wDenoised} $t2wBrain -f 0.35 -R -B -m
      # run antsRegistration on data
      antsRegistration --dimensionality 3 --output ${b0Nonlin} --initial-moving-transform [${t2wBrain}.nii.gz,${b0Denoised},1] \
        --transform Rigid[0.1] --metric Mattes[${t2wBrain}.nii.gz,${b0Denoised},1,32,Regular,0.25] --convergence [2000x2000x2000x2000x2000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
        --transform Affine[0.1] --metric Mattes[${t2wBrain}.nii.gz,${b0Denoised},1,32,Regular,0.25] --convergence [1000x1000x1000x1000x1000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
        --transform SyN[0.15,2,0] --metric CC[${t2wBrain}.nii.gz,${b0Denoised},1,4] --convergence [1000x1000x1000x1000x1000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
        --use-histogram-matching 1 --verbose 1 --random-seed 13983981 --winsorize-image-intensities [0.005,0.995] --write-composite-transform 1
      
      antsApplyTransforms -d 3 -n BSpline[3] -i ${b0Denoised} -o ${b0Nonlin}.nii.gz -t ${b0Nonlin}Composite.h5 -r $t2wBrain.nii.gz
      antsApplyTransforms -d 3 -e 3 -n BSpline[3] -i ${croppeddwi} -o ${dwiNonlin}.nii.gz -t ${b0Nonlin}Composite.h5 -r $t2wBrain.nii.gz
      #antsApplyTransforms -d 3 -n BSpline[3] -i ${t2wBrain}_mask.nii.gz -o ${t2wBrain}_mask_coreg.nii.gz -t ${b0Nonlin}Composite.h5 -r $t2wBrain.nii.gz
      #fslmaths ${t2wBrain}_mask.nii.gz -bin ${t2wBrain}_masknii.gz
      dtifit -k ${dwiNonlin}.nii.gz -m ${t2wBrain}_mask.nii.gz -o $dtiFitOutput -r ${rawdata}/${participant_id}/dwi/${participant_id}_${session_id}_DTI-30_DIRECTIONS.bvec -b ${rawdata}/${participant_id}/dwi/${participant_id}_${session_id}_DTI-30_DIRECTIONS.bval
      # antsApplyTransforms -d 3 -i sub-CBFBM41T1_ses-20230327100040_dwi_b0_mean.nii.gz -o sub-CBFBM41T1_ses-20230327100040_dwi_nonlin.nii.gz -t sub-CBFBM41T1_ses-20230327100040_dwi_b0_nonlinComposite.h5 -r sub-CBFBM41T1_ses-20230327100040_anat-T2w_resamp2dwi.nii.gz 
    fi
    done < ${rawdata}/${participant_id}/sessions.tsv
done < ${rawdata}/participants.tsv
