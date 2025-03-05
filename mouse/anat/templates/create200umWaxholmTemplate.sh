#!/bin/bash
# run from templates folder
3dresample -dxyz 0.2 0.2 0.2 -input canon_T2W_r.nii.gz -prefix WHS_0.5_T2w_200um.nii.gz 
3dresample -master WHS_0.5_T2w_200um.nii.gz -input WHS_0.5_Labels.nii.gz -prefix WHS_0.5_Labels_200um.nii.gz