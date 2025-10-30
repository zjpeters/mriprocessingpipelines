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

#convert bval and bvec into b matrix:
1dDW_Grad_o_Mat++                         \
   -in_row_vec   sub-010_dwi.bvec                 \
   -in_bvals     sub-010_dwi.bval                 \
   -out_col_matA sub-010_dwi_matA.dat \
   -flip_y


#convert nii.gz to BRIK HEAD format:
3dcopy sub-010_dwi.nii.gz sub-010_dwi
3dcopy sub-010/sub-010_dwi_mask.nii.gz sub-010_dwi_mask

#Correct Eddy Distortions
3dAllineate -base 'sub-010_dwi+orig.HEAD[0]' -input 'sub-010_dwi+orig.HEAD' \
-prefix sub-010_dwi_al -cost mutualinfo -verb -EPI

3dDWItoDT -prefix test_tensors.nii.gz \
    -mask sub-010_dwi_mask+orig.BRIK.gz \
    -reweight -eigs \
    -bmatrix_FULL sub-010_dwi_matA.dat sub-010_dwi.nii.gz

#visualize DTI Data in AFNI
3dcalc -prefix DTIout -a 'test_tensors.nii.gz[9..11]' -c 'test_tensors.nii.gz[18]' -expr 'c*STEP(c-0.25)*255*ABS(a)'
3dThreetoRGB -prefix DTIColorMap -anat 'DTIout+orig.[0]' 'DTIout+orig.[1]' 'DTIout+orig.[2]'
afni