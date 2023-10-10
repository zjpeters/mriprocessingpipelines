#!/bin/bash
# uses AFNI, ANTs, FSL
if [ $# != 3 ] ; then
  echo "Usage: `basename $0` {dwiImage} {t2wImage} {outputLocation}"
  exit 0;
fi
export inputDwi=$1
export inputT2w=$2
derivatives=$3
bvalFile=${inputDwi//.nii.gz/.bval}
# uses input image to extrapolate participant and session id
filename=$(basename $inputDwi)
participant_id=${filename%%_ses-*}
# session_id=$(basename $inputScan)
session_id=$(echo $filename | sed 's/^.*\(ses-.*_\).*$/\1/')
session_id=${session_id%%_*}
# modality=$(basename $inputScan)
modality=${filename//${participant_id}_${session_id}_}
modality=${modality%%.nii.gz}
# outputFolder=${derivatives}/${participant_id}
outputNameBase=${derivatives}/${participant_id}/${participant_id}_${session_id}_${modality}

# rawdata=~/rdss_tnj/twiceExceptional/rawdata
# derivatives=~/rdss_tnj/twiceExceptional/derivatives
# sourcedata=~/rdss_tnj/twiceExceptional/sourcedata

#input files
# dwiFor=${rawdata}/${participant_id}/${session_id}/dwi/${participant_id}_${session_id}_DTI_32_DIR.nii.gz
# t2wImage=${rawdata}/${participant_id}/${session_id}/anat/${participant_id}_${session_id}_Sag_CUBE_T2.nii.gz

# output files
croppeddwi=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_cropped.nii.gz
b0For=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_b0.nii.gz
t2wResamp=${derivatives}/${participant_id}/${participant_id}_${session_id}_anat-T2w_resamp2dwi.nii.gz
t2wInm=${derivatives}/${participant_id}/${participant_id}_${session_id}_anat-T2w_resamp2dwi_inm.nii.gz
t2wDenoised=${derivatives}/${participant_id}/${participant_id}_${session_id}_anat-T2w_resamp2dwi_denoised.nii.gz
b0Nonlin=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_b0_nonlin
dwiNonlin=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_nonlin
resampleDwi=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_resampled.nii.gz
dtiFitOutput=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_nonlin_proc
b0Mean=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_b0_mean.nii.gz
b0Denoised=${derivatives}/${participant_id}/${participant_id}_${session_id}_dwi_b0_mean_denoised.nii.gz

if [ ! -f $inputDwi ]; then
    echo "$inputDwi does not exist"
    continue
elif [ -f ${b0Nonlin}.nii.gz ]; then
    echo "processing has already been run for $participant_id $session_id"
    continue
else
    echo "Beginning processing of $participant_id $session_id"
    if [ ! -d ${derivatives}/${participant_id} ]; then
        mkdir -p ${derivatives}/${participant_id}
    fi
    # count number of b0 images 
    bvals=$(cat ${bvalFile})
    nb0s=0
    for i in $bvals; do
    if [ $i == 0 ]; then
        ((nb0s++))
    fi
    done

    # resample into template space
    3dresample -dxyz 1 1 1 -input ${inputDwi} -prefix ${resampleDwi} 
    # need to first check if image has even number of slices in each direction
    xDim=$(fslval $resampleDwi dim1)
    yDim=$(fslval $resampleDwi dim2)
    zDim=$(fslval $resampleDwi dim3)
    tDim=$(fslval $resampleDwi dim4)
    if [ $((xDim%2)) != 0 ]; then
    ((xDim--))
    fi
    if [ $((yDim%2)) != 0 ]; then
    ((yDim--))
    fi
    if [ $((zDim%2)) != 0 ]; then
    ((zDim--))
    fi
    # crop images in case of an odd numbered dimension
    fslroi $resampleDwi $croppeddwi 0 $xDim 0 $yDim 0 $zDim 0 $tDim
    fslroi $croppeddwi $b0For 0 $xDim 0 $yDim 0 $zDim 0 $nb0s
    fslmaths $b0For -Tmean $b0Mean
    3dresample -master $croppeddwi -input ${t2wImage} -prefix ${t2wResamp}
    # intensity nmormalize
    meanIntensity=$(fslstats $b0Mean -m)
    fslmaths $t2wResamp -inm $meanIntensity $t2wInm

    DenoiseImage -d 3 -n Rician -s 1 -p 1 -r 2 -v 1 -i ${t2wInm} -o [${t2wDenoised},${t2wDenoised//denoised/noise}]
    DenoiseImage -d 3 -n Rician -s 1 -p 1 -r 2 -v 1 -i ${b0Mean} -o [${b0Denoised},${b0Denoised//denoised/noise}]
    t2wBrain=${derivatives}/${participant_id}/${participant_id}_${session_id}_anat-T2w_resamp2dwi_denoised_brain
    bet ${t2wDenoised} $t2wBrain -f 0.35 -R -B -m
    # run antsRegistration on b0 and apply to entire dwi dataset
    antsRegistration --dimensionality 3 --output ${b0Nonlin} --initial-moving-transform [${t2wBrain}.nii.gz,${b0Denoised},1] \
    --transform Rigid[0.1] --metric Mattes[${t2wBrain}.nii.gz,${b0Denoised},1,32,Regular,0.25] --convergence [2000x2000x2000x2000x2000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
    --transform Affine[0.1] --metric Mattes[${t2wBrain}.nii.gz,${b0Denoised},1,32,Regular,0.25] --convergence [1000x1000x1000x1000x1000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
    --transform SyN[0.15,2,0] --metric CC[${t2wBrain}.nii.gz,${b0Denoised},1,4] --convergence [1000x1000x1000x1000x1000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
    --use-histogram-matching 1 --verbose 1 --random-seed 13983981 --winsorize-image-intensities [0.005,0.995] --write-composite-transform 1
    
    antsApplyTransforms -d 3 -n BSpline[3] -i ${b0Denoised} -o ${b0Nonlin}.nii.gz -t ${b0Nonlin}Composite.h5 -r $t2wBrain.nii.gz
    antsApplyTransforms -d 3 -e 3 -n BSpline[3] -i ${croppeddwi} -o ${dwiNonlin}.nii.gz -t ${b0Nonlin}Composite.h5 -r $t2wBrain.nii.gz

    dtifit -k ${dwiNonlin}.nii.gz -m ${t2wBrain}_mask.nii.gz -o $dtiFitOutput -r ${bvalFile//.bval/.bvec} -b ${bvalFile}
fi
