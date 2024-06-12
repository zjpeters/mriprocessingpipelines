#!/bin/bash

helpRequest() {
    [ "$#" -le "2" ] || [ "$1" = '-h' ] || [ "$1" = '-help' ]
}
if helpRequest "$@"; then
    echo "Usage: `basename $0` {rawdata} {derivatives} {modality}"
    echo "Performs preprocessing on anatomical data."
    echo "rawdata is the folder containing subject folders and participants.tsv"
    echo "derivatives is the folder where data is saved to."
    echo "outputFilename is what you want to name your file, default is 'volume.tsv'"
    exit 0;
fi
scriptPath=`dirname $0`
scriptPath=`readlink -f $scriptPath`
# DIR_PROJECT=/media/zjpeters/Samsung_T5/marcinkiewcz/dreaddFmri
rawdata=$1
derivatives=$2
# add modality as an option later
MODALITY=$3
###################################################################################
# need to update to a better naming for the template and mask
###################################################################################

FIXED=${scriptPath}/templates/WHS_0.5_T1w_200um.nii.gz
ATLAS_LABELS=${scriptPath}/templates/WHS_0.5_Labels_LHRH_200um.nii.gz
FIXED_MASK=${scriptPath}/templates/WHS_0.5_Labels_Brain_200um.nii.gz

ISOTROPIC_RES=0.2
tVal=3300
vVal=340
kVal=6
DIR_SUMMARY=${derivatives}/summary
SUMMARY_FILE=${DIR_SUMMARY}/volumes.tsv
mkdir -p ${DIR_SUMMARY}
if [ -f ${SUMMARY_FILE} ]; then
      rm ${SUMMARY_FILE}
fi
touch ${SUMMARY_FILE}
    
while read PID; do
  [ "$PID" == participant_id ] && continue;  # skips the header
  while read SID; do
    [ "$SID" == session_id ] && continue;  # skips the header
    PIDSTR=${PID}_${SID}
    DIRPID=${PID}/${SID}

    # DIR_PREP=${DIR_PROJECT}/derivatives/inc/prep/${DIRPID}/anat
    DIR_ANAT=${derivatives}/${DIRPID}/anat
    DIR_MASK=${DIR_ANAT}/mask
    DIR_XFM=${DIR_ANAT}/xfm
    DIR_LABEL=${DIR_ANAT}/label
    LABEL=${DIR_ANAT}/label/${PIDSTR}_label-allen.nii.gz

    XFM=${DIR_XFM}/reg_AllenComposite.h5
    XFM_INVERSE=${DIR_XFM}/reg_AllenInverseComposite.h5

    ## set image list (order of priority determined by MODLS and BIDS flags
    IMG_RAW=${rawdata}/${DIRPID}/anat/${PIDSTR}_${MODALITY}.nii.gz
    MASK=${DIR_MASK}/${PIDSTR}_RATS_MM_t${tVal}_v${vVal}_k${kVal}_mask-brain.nii.gz
    MASK_RESAMP=${DIR_MASK}/${PIDSTR}_RATS_MM_t${tVal}_v${vVal}_k${kVal}_mask-brain_${ISOTROPIC_RES}mm.nii.gz
    IMG_DEOBLIQUE=${DIR_ANAT}/${PIDSTR}_${MODALITY}_deoblique.nii.gz
    
    IMG_RAI=${DIR_ANAT}/${PIDSTR}_RAI.nii.gz
    NEW_ORIENT=LIP
    IMG_REORIENT=${DIR_ANAT}/${PIDSTR}_${MODALITY}_${NEW_ORIENT}.nii.gz
    
    IMG_NATIVE=${DIR_ANAT}/native/${PIDSTR}_${MODALITY}-brain.nii.gz
    # currently set to use the denoised but not mean normalized version
    IMG_RESAMP=${DIR_ANAT}/${PIDSTR}_prep-denoise_${ISOTROPIC_RES}mm_${MODALITY}.nii.gz    
    if [ ! -f ${XFM} ]; then
      echo "beginning registration ${PIDSTR}"

      # mkdir -p ${DIR_PREP}
      mkdir -p ${DIR_LABEL}


      # 3dresample -orient RAI -input ${IMG_DEOBLIQUE} -prefix ${IMG_RAI}
      # 3dcopy ${IMG_RAI} ${IMG_RIP}
      # 3drefit -orient RIP ${IMG_RIP}
      if [ ! -f ${MASK} ]; then
        # performs deobliquing and then sets orientation to match mouse
        3dWarp -deoblique -prefix ${IMG_DEOBLIQUE} ${IMG_RAW}
        ORIENT_CODE=$(3dinfo -orient ${IMG_DEOBLIQUE})
        echo $ORIENT_CODE
        X=${ORIENT_CODE:0:1}
        Y=${ORIENT_CODE:2:1}
        if [[ "${ORIENT_CODE:1:1}" == "P" ]]; then
          Z=A
        elif [[ "${ORIENT_CODE:1:1}" == "A" ]]; then
          Z=P
        elif [[ "${ORIENT_CODE:1:1}" == "S" ]]; then
          Z=I
        elif [[ "${ORIENT_CODE:1:1}" == "I" ]]; then
          Z=S
        fi
        # Z=${ORIENT_CODE:1:1}
        # NEW_CODE="${X}${Y}${Z}"
        # echo $NEW_CODE
        3dresample -orient RAI -prefix ${IMG_RAI} -input ${IMG_DEOBLIQUE}
        3dcopy ${IMG_RAI} ${IMG_REORIENT}
        3drefit -orient ${NEW_ORIENT} ${IMG_REORIENT}
        # bias correction --------------------------------------------------------------
        echo "Generating a whole brain mask for processing"
        N4BiasFieldCorrection -d 3 -i ${IMG_REORIENT} -r 1 -s 4 -c [50x50x50x50,0.0] -b [6,3] -t [0.15,0.01,200] -o [${DIR_ANAT}/${PIDSTR}_prep-biasN4_${MODALITY}.nii.gz,${DIR_ANAT}/${PIDSTR}_biasField_${MODALITY}.nii.gz] -v 1
        # denoise ----------------------------------------------------------------------
        DenoiseImage -d 3 -n Rician -s 1 -p 1 -r 2 -v 1 -i ${DIR_ANAT}/${PIDSTR}_prep-biasN4_${MODALITY}.nii.gz -o [${DIR_ANAT}/${PIDSTR}_prep-denoise_${MODALITY}.nii.gz,${DIR_ANAT}/${PIDSTR}_prep-noise_${MODALITY}.nii.gz]
        # intensity normalization to mean value of 3000
        fslmaths ${DIR_ANAT}/${PIDSTR}_prep-denoise_${MODALITY}.nii.gz -inm 3000 ${DIR_ANAT}/${PIDSTR}_prep-denoise_inm3000_${MODALITY}.nii.gz
        # run RATS_MM to generate mask
        mkdir -p ${DIR_MASK}
        echo "Running RATS_MM on denoised image"
        RATS_MM -t ${tVal} -v ${vVal} -k ${kVal} ${DIR_ANAT}/${PIDSTR}_prep-denoise_inm3000_${MODALITY}.nii.gz ${MASK}
        rm ${DIR_ANAT}/${PIDSTR}_prep-biasN4_${MODALITY}.nii.gz ${DIR_ANAT}/${PIDSTR}_biasField_${MODALITY}.nii.gz ${DIR_ANAT}/${PIDSTR}_prep-denoise_${MODALITY}.nii.gz ${DIR_ANAT}/${PIDSTR}_prep-noise_${MODALITY}.nii.gz
      fi
      echo "Performing bias field correction"
      N4BiasFieldCorrection -d 3 -i ${IMG_REORIENT} -x ${MASK} -r 1 -s 4 -c [50x50x50x50,0.0] -b [6,3] -t [0.15,0.01,200] -o [${DIR_ANAT}/${PIDSTR}_prep-biasN4_${MODALITY}.nii.gz,${DIR_ANAT}/${PIDSTR}_biasField_${MODALITY}.nii.gz] -v 1
      # denoise ----------------------------------------------------------------------
      echo "Denoising image"
      DenoiseImage -d 3 -n Rician -s 1 -p 1 -r 2 -v 1 -x ${MASK} -i ${DIR_ANAT}/${PIDSTR}_prep-biasN4_${MODALITY}.nii.gz -o [${DIR_ANAT}/${PIDSTR}_prep-denoise_${MODALITY}.nii.gz,${DIR_ANAT}/${PIDSTR}_prep-noise_${MODALITY}.nii.gz]
      # prepare to register allen to native ------------------------------------------
      mkdir -p ${DIR_ANAT}/native
      mkdir -p ${DIR_XFM}

      3dresample -dxyz ${ISOTROPIC_RES} ${ISOTROPIC_RES} ${ISOTROPIC_RES} \
           -prefix  ${IMG_RESAMP} \
           -input ${DIR_ANAT}/${PIDSTR}_prep-denoise_${MODALITY}.nii.gz
      
      # mkdir -p ${DIR_ANAT}/reg_Allen
      3dresample -dxyz ${ISOTROPIC_RES} ${ISOTROPIC_RES} ${ISOTROPIC_RES} \
            -prefix ${MASK_RESAMP} \
            -input ${MASK}
      fslmaths ${IMG_RESAMP} -mas ${MASK_RESAMP} ${IMG_NATIVE}
      
      ## this should be the same as the previous coregistrationChef
      ## note: I've set it to output to the ${DIR_XFM} folder, which is slightly different
      echo "Registering image to template space"
      #--write-composite-transform 1 \
      #--collapse-output-transforms 0 \
      #--initialize-transforms-per-stage 1 \
      antsRegistration \
        --dimensionality 3 \
        --output ${DIR_XFM}/reg_Allen \
        --write-composite-transform 1 \
        --collapse-output-transforms 0 \
        --initialize-transforms-per-stage 1 \
        --initial-moving-transform [${FIXED},${IMG_NATIVE},1] \
        --transform Rigid[0.1] --metric MI[${FIXED},${IMG_NATIVE},1,32,Regular,0.25] --masks [${FIXED_MASK},${MASK_RESAMP}] --convergence [2000x2000x2000x2000x2000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
        --transform Affine[0.1] --metric MI[${FIXED},${IMG_NATIVE},1,32,Regular,0.25] --masks [${FIXED_MASK},${MASK_RESAMP}] --convergence [2000x2000x2000x2000x2000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
        --transform SyN[0.1,3,0] --metric CC[${FIXED},${IMG_NATIVE},1,4] --masks [${FIXED_MASK},${MASK_RESAMP}] --convergence [100x70x50x20,1e-6,10] --smoothing-sigmas 3x2x1x0vox --shrink-factors 8x4x2x1 \
        --winsorize-image-intensities [0.005,0.995] \
        --float 1 \
        --verbose 1 \
        --random-seed 15754459
      antsApplyTransforms -d 3 -n MultiLabel \
        -i ${ATLAS_LABELS} \
        -o ${LABEL} \
        -t ${XFM_INVERSE} \
        -r ${IMG_NATIVE}
      # antsApplyTransforms -d 3 \
      #   -i ${IMG_RESAMP} \
      #   -o ${DIR_ANAT}/${PIDSTR}_reg_to_template.nii.gz \
      #   -t ${XFM} \
      #   -r ${FIXED}
    else 
    ## Haven't updated this bit yet, since I want to be able to see the naming of above
    # back propagate labels to native space ----------------------------------------
    # XFM4="[${DIR_XFM}/${PIDSTR}_mod-${MODALITY}-brain_from-native_to-allen_xfm-affine.mat,1]"
    # XFM3=${DIR_XFM}/${PIDSTR}_mod-${MODALITY}-brain_from-native_to-allen_xfm-syn+inverse.nii.gz
      echo "registration of ${PIDSTR} already done"
      mkdir -p ${DIR_ANAT}/label/allen
      antsApplyTransforms -d 3 -n MultiLabel \
        -i ${ATLAS_LABELS} \
        -o ${LABEL} \
        -t ${XFM_INVERSE} \
        -r ${IMG_RESAMP}
    fi
    3dROIstats -mask ${LABEL} -nzvoxels ${IMG_RESAMP} >>${DIR_SUMMARY}/volumes.tsv
  done < ${rawdata}/${PID}/sessions.tsv
done < ${rawdata}/participants.tsv

