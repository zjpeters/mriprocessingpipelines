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
    
while read PID sex; do
  [ "$PID" == participant_id ] && continue;  # skips the header
  while read SID acqdate roix roiy roiz; do
    [ "$SID" == session_id ] && continue;  # skips the header
    PIDSTR=${PID}_${SID}
    DIRPID=${PID}/${SID}

    # DIR_PREP=${DIR_PROJECT}/derivatives/inc/prep/${DIRPID}/anat
    DIR_ANAT=${derivatives}/anat
    DIR_MASK=${DIR_ANAT}/mask
    DIR_XFM=${derivatives}/xfm
    DIR_LABEL=${DIR_ANAT}/label
    LABEL=${DIR_ANAT}/label/${PIDSTR}_label-DSURQE.nii.gz

    XFM=${DIR_XFM}/${PIDSTR}_AllenComposite.h5
    XFM_INVERSE=${DIR_XFM}/reg_AllenInverseComposite.h5

    ## set image list (order of priority determined by MODLS and BIDS flags
    IMG_RAW=${rawdata}/${DIRPID}/anat/${PIDSTR}_${MODALITY}.nii.gz
    MASK=${DIR_MASK}/${PIDSTR}_RATS_MM_t${tVal}_v${vVal}_k${kVal}_mask-brain.nii.gz
    MASK_RESAMP=${DIR_MASK}/${PIDSTR}_RATS_MM_t${tVal}_v${vVal}_k${kVal}_mask-brain_${ISOTROPIC_RES}mm.nii.gz
    IMG_DEOBLIQUE=${DIR_ANAT}/${PIDSTR}_${MODALITY}_deoblique.nii.gz
    
    IMG_RAI=${DIR_ANAT}/${PIDSTR}_RAI.nii.gz
    NEW_ORIENT=LIP
    IMG_REORIENT=${DIR_ANAT}/${PIDSTR}_${MODALITY}_${NEW_ORIENT}.nii.gz

    # currently set to use the denoised but not mean normalized version
    IMG_RESAMP=${DIR_ANAT}/${PIDSTR}_prep-denoise_${ISOTROPIC_RES}mm_${MODALITY}.nii.gz    
    if [ ! -f ${XFM} ]; then
      echo "beginning registration ${PIDSTR}"

      # mkdir -p ${DIR_PREP}
      mkdir -p ${DIR_LABEL}

      # 3dresample -orient RAI -input ${IMG_DEOBLIQUE} -prefix ${IMG_RAI}
      # 3dcopy ${IMG_RAI} ${IMG_RIP}
      # 3drefit -orient RIP ${IMG_RIP}
    fi
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
    3dresample -orient RAI -prefix ${IMG_RAI} -input ${IMG_DEOBLIQUE}
    3dcopy ${IMG_RAI} ${IMG_REORIENT}
    3drefit -orient ${NEW_ORIENT} ${IMG_REORIENT}
    # bias correction --------------------------------------------------------------
    echo "Generating a whole brain mask for processing"
    N4BiasFieldCorrection -d 3 -i ${IMG_REORIENT} -r 1 -s 4 -c [50x50x50x50,0.0] -b [6,3] -t [0.15,0.01,200] -o [${DIR_ANAT}/${PIDSTR}_prep-biasN4_${MODALITY}.nii.gz,${DIR_ANAT}/${PIDSTR}_biasField_${MODALITY}.nii.gz] -v 1
    # denoise ----------------------------------------------------------------------
    DenoiseImage -d 3 -n Rician -s 1 -p 1 -r 2 -v 1 -i ${DIR_ANAT}/${PIDSTR}_prep-biasN4_${MODALITY}.nii.gz -o [${DIR_ANAT}/${PIDSTR}_prep-denoise_${MODALITY}.nii.gz,${DIR_ANAT}/${PIDSTR}_prep-noise_${MODALITY}.nii.gz]
    # intensity normalization to mean value of 3000
    fslmaths ${DIR_ANAT}/${PIDSTR}_prep-denoise_${MODALITY}.nii.gz -inm ${tVal} ${DIR_ANAT}/${PIDSTR}_prep-denoise_inm3000_${MODALITY}.nii.gz
    # run RATS_MM to generate mask
    mkdir -p ${DIR_MASK}
    echo "Running RATS_MM on denoised image"
    RATS_MM -t ${tVal} -v ${vVal} -k ${kVal} ${DIR_ANAT}/${PIDSTR}_prep-denoise_inm3000_${MODALITY}.nii.gz ${MASK}
  done < ${rawdata}/${PID}/sessions.tsv
done < ${rawdata}/participants.tsv

