#!/bin/bash
if [ $# != 3 ] ; then
  echo "Usage: `basename $0` {subjectID} {subject-freesurfer-directory} {outputDirectory}"
  exit 0;
fi
subjectID=$1
SUBJECT_FREESURFER=$2
meshDir=$3
#create subject directory for freesurfer data
if [ ! -f $SUBJECT_FREESURFER/surf/lh.pial* ]; then
    echo "No pial files found for $subjectID in:"
    echo "$SUBJECT_FREESURFER"
    exit 1;
fi
if [ ! -d $meshDir/${subjectID} ]; then
  mkdir -p $meshDir/${subjectID}
fi
echo "Converting surface files to stl format"
# convert lh.pial and rh.pial to stl and name as cortical.stl
mris_convert ${SUBJECT_FREESURFER}/surf/lh.pial* $meshDir/${subjectID}/${subjectID}_left_cortical.stl
mris_convert ${SUBJECT_FREESURFER}/surf/rh.pial* $meshDir/${subjectID}/${subjectID}_right_cortical.stl

# extract subcortical regions
mri_convert ${SUBJECT_FREESURFER}/mri/aseg.mgz $meshDir/${subjectID}/${subjectID}_aseg.nii.gz -it mgz -ot nii

# binarize areas

mri_binarize --i $meshDir/${subjectID}/${subjectID}_aseg.nii.gz --match 7 8 16 28 46 47 60 251 252 253 254 255 --o $meshDir/${subjectID}/${subjectID}_subcortical_bin.nii.gz

fslmaths $meshDir/${subjectID}/${subjectID}_aseg.nii.gz -mas $meshDir/${subjectID}/${subjectID}_subcortical_bin.nii.gz $meshDir/${subjectID}/${subjectID}_subcortical

fslmaths $meshDir/${subjectID}/${subjectID}_subcortical -bin $meshDir/${subjectID}/${subjectID}_subcortical
fslmaths $meshDir/${subjectID}/${subjectID}_subcortical -fillh $meshDir/${subjectID}/${subjectID}_subcortical

mri_tessellate $meshDir/${subjectID}/${subjectID}_subcortical.nii.gz 1 $meshDir/${subjectID}/${subjectID}_subcortical_surf

mris_convert $meshDir/${subjectID}/${subjectID}_subcortical_surf $meshDir/${subjectID}/${subjectID}_subcortical_surf.stl
rm $meshDir/${subjectID}/*.nii.gz
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
