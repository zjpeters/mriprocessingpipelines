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
scriptPath=/Users/sophieborghoff/Documents/MDthesis/mriprocessingpipelines/mouse/anat

echo $scriptPath
scriptPath=`readlink -f $scriptPath`

imageLocation=$1
derivatives=$2

imageName=$(basename ${imageLocation})
subID=${imageName%%_*}

outputDir="${derivatives}/${subID}"
outputBaseName="${outputDir}/${imageName%%.nii.gz}"
#input files
    imageName=$(basename ${imageLocation})
    subID=${imageName%%_*}
    IMG_NATIVE="${outputBaseName}"_bf_corrected_denoised.nii.gz
    echo $IMG_NATIVE
    dtiOut="${outputBaseName}"_DTI
    dtiColor="${outputBaseName}"_DTIColorMap
   
###
XFMdir="${derivatives}/${subID}/XFM"
if [ ! -d "${XFMdir}" ]; then 
   mkdir "${XFMdir}"
fi
echo $XFMdir
XFMBaseName="${XFMdir}/${imageName%%.nii.gz}"

LABEL=${XFMBaseName}_label-allen.nii.gz
REG_IMG=${XFMBaseName}_reg_to_template.nii.gz

    XFM=${XFMdir}/reg_AllenComposite.h5
    XFM_INVERSE=${XFMdir}/reg_AllenInverseComposite.h5


# working on registration 



FIXED=${scriptPath}/templates/AFNI_AllenMouseCCF3/AFNI_allen2020_template_200um.nii.gz
ATLAS_LABELS=${scriptPath}/templates/AFNI_AllenMouseCCF3/AFNI_allen2020_atlas_200um.nii.gz
FIXED_MASK=${scriptPath}/templates/AFNI_AllenMouseCCF3/AFNI_allen2020_atlas_mask_200um.nii.gz


antsRegistration \
        --dimensionality 3  --output ${XFMdir}/reg_Allen \
        --write-composite-transform 1 \
        --collapse-output-transforms 0 \
        --initialize-transforms-per-stage 1 \
        --use-histogram-matching \
        --initial-moving-transform [${FIXED},${IMG_NATIVE},1] \
        --transform Rigid[0.1] --metric MI[${FIXED},${IMG_NATIVE},1,32,Regular,0.25] --masks [${FIXED_MASK},${MASK_RESAMP}] --convergence [2000x2000x2000x2000x2000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
        --transform Affine[0.1] --metric MI[${FIXED},${IMG_NATIVE},1,32,Regular,0.25] --masks [${FIXED_MASK},${MASK_RESAMP}] --convergence [2000x2000x2000x2000x2000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
        --transform SyN[0.15,3,0] --metric CC[${FIXED},${IMG_NATIVE},1,4] --masks [${FIXED_MASK},${MASK_RESAMP}] --convergence [100x70x50x20,1e-6,10] --smoothing-sigmas 3x2x1x0vox --shrink-factors 8x4x2x1 \
        --winsorize-image-intensities [0.005,0.995] \
        --float 1 \
        --verbose 1 \
        --random-seed 15754459

antsApplyTransforms -d 3 -n MultiLabel \
        -i ${ATLAS_LABELS} \
        -o ${LABEL} \
        -t ${XFM_INVERSE} \
        -r ${IMG_NATIVE}
        echo ${REG_IMG}
antsApplyTransforms -d 4 \
        -i ${IMG_NATIVE} \
        -o ${REG_IMG} \
        -t ${XFM} \
        -r ${FIXED} --verbose 1
antsApplyTransforms -d 4 \
        -i ${dtiOut} \
        -o ${REG_IMG} \
        -t ${XFM} \
        -r ${FIXED} --verbose 1
antsApplyTransforms -d 3 \
        -i ${dtiColor} \
        -o ${REG_IMG} \
        -t ${XFM} \
        -r ${FIXED} --verbose 1
