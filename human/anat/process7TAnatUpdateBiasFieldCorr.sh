#!/bin/bash
# uses AFNI, ANTs, FSL
if [ $# != 2 ] ; then
  echo "Usage: `basename $0` {subjectImage} {outputLocation}"
  exit 0;
fi
export inputScan=$1
derivatives=$2

# setting static variables
template=$FSLDIR/data/standard/MNI152_T1_0.5mm.nii.gz
templateMask=$FSLDIR/data/standard/MNI152_T1_0.5mm_brain_mask.nii.gz

filename=$(basename $inputScan)
participant_id=${filename%%_ses-*}
# session_id=$(basename $inputScan)
session_id=$(echo $filename | sed 's/^.*\(ses-.*_\).*$/\1/')
session_id=${session_id%%_*}
modality=$(basename $inputScan)
modality=${modality//${participant_id}_${session_id}_}
modality=${modality%%.nii.gz}
outputFolder=${derivatives}/${participant_id}
SUBJECTS_DIR=$outputFolder
outputNameBase=${derivatives}/${participant_id}/${participant_id}_${session_id}_${modality}
if [ ! -f ${outputNameBase}_reorient_RPI_denoise_coreg_bfcorr.nii.gz ]; then
  if [ ! -d $outputFolder ]; then
    mkdir $outputFolder
  fi
  echo "Resampling $filename into RPI"
  3dresample -orient rpi -overwrite -prefix ${outputNameBase}_reorient_RPI.nii.gz -input $inputScan
  # not including mask in denoising since it hasn't been generated yet

  # general N4 command used
  echo "Running bias field correction on $filename"
  # updated from -b [50,3] with no -t
  N4BiasFieldCorrection -d 3 -i ${outputNameBase}_reorient_RPI.nii.gz -x ${templateMask} -r 1 -s 4 -c [50x50x50x50,0.0] -b [50,3] -t [0.15,0.01,200] -o [${outputNameBase}_reorient_RPI_bfcorr.nii.gz,${outputNameBase}_reorient_RPI_bf.nii.gz]

  echo "Denoising $filename"
  DenoiseImage -d 3 -n Rician -s 1 -p 1 -r 2 -v 1 -i ${outputNameBase}_reorient_RPI_bfcorr.nii.gz -o [${outputNameBase}_reorient_RPI_bfcorr_denoise.nii.gz,${outputNameBase}_reorient_RPI_bfcorr_noise.nii.gz]
  # run antsRegistration on data
  echo "Registering $filename to $template"
  antsRegistration --dimensionality 3 --output ${outputNameBase}_reorient_RPI_bfcorr_denoise_coreg --initial-moving-transform [${template},${outputNameBase}_reorient_RPI_bfcorr_denoise.nii.gz,1] \
    --transform Rigid[0.1] --metric Mattes[${template},${outputNameBase}_reorient_RPI_denoise.nii.gz,1,32,Regular,0.25] --convergence [2000x2000x2000x2000x2000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
    --transform Affine[0.1] --metric Mattes[${template},${outputNameBase}_reorient_RPI_denoise.nii.gz,1,32,Regular,0.25] --convergence [1000x1000x1000x1000x1000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
    --use-histogram-matching 1 --verbose 1 --random-seed 13983981 --winsorize-image-intensities [0.005,0.995] --write-composite-transform 1

  # add back in for nonlinear
  #--transform Syn[0.1,3,0] --metric CC[${template},${outputNameBase}_reorient_RPI_denoise.nii.gz,1,4,Regular,0.25] --convergence [1000x1000x1000x1000x1000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \

  antsApplyTransforms -d 3 -n BSpline[3] -i ${outputNameBase}_reorient_RPI_bfcorr_denoise.nii.gz -o ${outputNameBase}_reorient_RPI_bfcorr_denoise_coreg.nii.gz -t ${outputNameBase}_reorient_RPI_bfcorr_denoise_coregComposite.h5 -r $template

elif [ -f ${outputNameBase}_reorient_RPI_bfcorr_denoise.nii.gz ]; then
  echo "Preprocessing has already been run"
  exit 0
fi


# run freesurfer
# if [ -d $SUBJECTS_DIR/${participant_id}_${session_id}/mri/orig ]; then
#   echo "Freesurfer has already been run on ${participant_id}_${session_id}"
# else
#   echo "Running freesurfer on $filename"
#   mkdir -p $SUBJECTS_DIR/${participant_id}_${session_id}/mri/orig
#   mri_convert ${outputNameBase}_reorient_RPI_denoise_coreg_bfcorr.nii.gz $SUBJECTS_DIR/${participant_id}_${session_id}/mri/orig/001.mgz
#   recon-all -subjid ${participant_id}_${session_id} -all -time -log logfile -sd $SUBJECTS_DIR -parallel
# fi