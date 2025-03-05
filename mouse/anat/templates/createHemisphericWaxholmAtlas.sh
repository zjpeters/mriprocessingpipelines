#!/bin/bash
# run from templates folder
# first fslroi removes the right hemisphere, second fslroi resets dimensions
fslroi WHS_0.5_Labels_200um.nii.gz WHS_0.5_Labels_LH_200um.nii.gz 0 27 0 110 0 55
fslroi WHS_0.5_Labels_LH_200um.nii.gz WHS_0.5_Labels_LH_200um.nii.gz 0 55 0 110 0 55
# subtract the LH image from the whole brain to give a right hemisphere image
fslmaths WHS_0.5_Labels_200um.nii.gz -sub WHS_0.5_Labels_LH_200um.nii.gz WHS_0.5_Labels_RH_200um.nii.gz -odt int
# add 27 to all labels in the RH and threshold at 28 to set backround to 0
fslmaths WHS_0.5_Labels_RH_200um.nii.gz -add 27 -thr 28 WHS_0.5_Labels_RH_200um.nii.gz -odt int
# add the two hemispheres back together to give the whole brain image
fslmaths WHS_0.5_Labels_LH_200um.nii.gz -add WHS_0.5_Labels_RH_200um.nii.gz WHS_0.5_Labels_LHRH_200um.nii.gz -odt int 
# generate a whole brain mask
fslmaths WHS_0.5_Labels_LHRH_200um.nii.gz -thr 0 -bin WHS_0.5_Labels_Brain_200um.nii.gz -odt int
# mask original T2w image with brain mask to remove skull
fslmaths WHS_0.5_T2w_200um.nii.gz -mas WHS_0.5_Labels_Brain_200um.nii.gz WHS_0.5_T2w_200um_skullstripped.nii.gz