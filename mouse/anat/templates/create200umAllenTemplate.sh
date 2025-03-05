#!/bin/bash
# run from templates folder
# starting as 25um image downsample to 200um
3dresample -dxyz 0.2 0.2 0.2 -input ./AFNI_AllenMouseCCF3/AFNI_allen2020_template.nii.gz -prefix ./AFNI_AllenMouseCCF3/AFNI_allen2020_template_200um.nii.gz 
3dresample -master ./AFNI_AllenMouseCCF3/AFNI_allen2020_template_200um.nii.gz -input ./AFNI_AllenMouseCCF3/AFNI_allen2020_atlas.nii.gz -prefix ./AFNI_AllenMouseCCF3/AFNI_allen2020_atlas_200um.nii.gz