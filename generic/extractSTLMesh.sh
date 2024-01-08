#!/bin/bash
if [ $# != 2 ] ; then
  echo "Usage: `basename $0` {subjID} {imageLoc}"
  exit 0;
fi
export subject=$1
inputScan=$2
tempDir=../tmp
meshDir=../brainMeshes
#create subject directory for freesurfer data
if [ ! -d $SUBJECTS_DIR/${subject}/mri/orig ]; then
  mkdir -p $SUBJECTS_DIR/${subject}/mri/orig
  echo "Running freesurfer pipeline for $subject"
  # use fslmaths to subsample the image into approximately 3T resolution
  fslmaths $inputScan -subsamp2 $tempDir/t1Subsamp

  # run recon-all on the subject
  mri_convert $tempDir/t1Subsamp.nii.gz $SUBJECTS_DIR/${subject}/mri/orig/001.mgz
  rm $tempDir/t1Subsamp.nii.gz
  recon-all -subjid ${subject} -all -time -log logfile -sd $SUBJECTS_DIR -parallel

else
  echo "$subject has already been run through freesurfer pipeline!"
fi
echo "Converting surface files to stl format"
# convert lh.pial and rh.pial to stl and name as cortical.stl
mris_convert $SUBJECTS_DIR/${subject}/surf/lh.pial* $meshDir/${subject}_right_cortical.stl
mris_convert $SUBJECTS_DIR/${subject}/surf/rh.pial* $meshDir/${subject}_left_cortical.stl

# extract subcortical regions
mri_convert $SUBJECTS_DIR/${subject}/mri/aseg.mgz $meshDir/${subject}_aseg.nii.gz -it mgz -ot nii

# binarize areas

mri_binarize --i $meshDir/${subject}_aseg.nii.gz --match 7 8 16 28 46 47 60 251 252 253 254 255 --o $meshDir/${subject}_subcortical_bin.nii.gz

fslmaths $meshDir/${subject}_aseg.nii.gz -mas $meshDir/${subject}_subcortical_bin.nii.gz $meshDir/${subject}_subcortical

fslmaths $meshDir/${subject}_subcortical -bin $meshDir/${subject}_subcortical
fslmaths $meshDir/${subject}_subcortical -fillh $meshDir/${subject}_subcortical

mri_tessellate $meshDir/${subject}_subcortical.nii.gz 1 $meshDir/${subject}_subcortical_surf

mris_convert $meshDir/${subject}_subcortical_surf $meshDir/${subject}_subcortical_surf.stl
#opens meshlab and allows for smoothing the output

#echo "In meshlab, smooth using the following drop downs:"
#echo ""
#echo "Filters -> Smoothing, fairing, and deformation"
#echo "->ScaleDependent Laplacian Smooth"
#echo ""
#echo "Use parameters:"
#echo "Smoothing steps: 100"
#echo "delta %: 0.100"
#echo ""
#echo "Once finished, select File -> Export Mesh and save with Binary encoding"
#meshlab $meshDir/${subject}_cortical.stl
