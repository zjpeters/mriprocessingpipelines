#!/bin/bash

helpRequest() {
    [ "$#" -le "1" ] || [ "$1" = '-h' ] || [ "$1" = '-help' ]
}
if helpRequest "$@"; then
    echo "Usage: `basename $0` {rawdata} {derivatives}"
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
MODALITY=MPRAGE_T1
###################################################################################
# need to update to a better naming for the template and mask
###################################################################################

FIXED=${FSLDIR}/data/standard/MNI152_T1_0.5mm.nii.gz
ATLAS_LABELS=${FSLDIR}/data/atlases/Schaefer2018_200Parcels_17Networks_order_FSLMNI152_0.5mm.nii.gz
FIXED_MASK=${FSLDIR}/data/standard/MNI152_T1_0.5mm_brain_mask.nii.gz

ISOTROPIC_RES=0.5

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
    LABEL=${DIR_ANAT}/label/${PIDSTR}_label-Schaefer200Parcels.nii.gz
    
    mkdir -p ${DIR_ANAT}
    XFM=${DIR_XFM}/reg_templateComposite.h5
    XFM_INVERSE=${DIR_XFM}/reg_templateInverseComposite.h5
    
    if [ ! -f ${XFM} ]; then
      echo "beginning registration ${PIDSTR}"

      mkdir -p ${DIR_LABEL}

      ## set image list (order of priority determined by MODLS and BIDS flags
      IMG_RAW=${rawdata}/${DIRPID}/anat/${PIDSTR}_${MODALITY}.nii.gz
      IMG_REORIENT=${DIR_ANAT}/${PIDSTR}_prep-RPI_${MODALITY}.nii.gz
      MASK=${DIR_MASK}/${PIDSTR}BrainExtractionMask.nii.gz
      MASK_RESAMP=${DIR_MASK}/${PIDSTR}BrainExtractionMask_${ISOTROPIC_RES}mm.nii.gz
      IMG_SMOOTH=${DIR_ANAT}/${PIDSTR}_prep-RPI_smooth_${MODALITY}.nii.gz
      3dresample -orient rpi -overwrite -prefix ${IMG_REORIENT} -input ${IMG_RAW}
      
      if [ ! -f ${MASK} ]; then
        # run antsBrainExtraction script on data to generate a mask to use in BF correction
        echo "Creating brain mask for subject"
        mkdir -p ${DIR_MASK}
        sigma=1.5
        IMG_SMOOTH_RESAMPLE=${DIR_ANAT}/${PIDSTR}_prep-RPI_smooth_${sigma}mm_${MODALITY}.nii.gz
        fslmaths ${IMG_REORIENT} -s ${sigma} ${IMG_SMOOTH}
        # 3dresample -dxyz 1 1 1 -prefix ${IMG_SMOOTH_RESAMPLE} -input ${IMG_SMOOTH}
      
        antsBrainExtraction.sh -d 3 -a ${IMG_SMOOTH} -e ${FIXED} -m ${FIXED_MASK} -o ${DIR_MASK}/${PIDSTR}
      fi
        
      # bias correction --------------------------------------------------------------
      echo "Running bias field correction"
      N4BiasFieldCorrection -d 3 -i ${IMG_REORIENT} -x ${MASK} -r 1 -s 4 -c [50x50x50x50,0.0] -b [50,3] -t [0.15,0.01,200] -o [${DIR_ANAT}/${PIDSTR}_prep-biasN4_${MODALITY}.nii.gz,${DIR_ANAT}/${PIDSTR}_biasField_${MODALITY}.nii.gz] -v 1
      # denoise ----------------------------------------------------------------------
      DenoiseImage -d 3 -n Rician -s 1 -p 1 -r 2 -v 1 -x ${MASK} -i ${DIR_ANAT}/${PIDSTR}_prep-biasN4_${MODALITY}.nii.gz -o [${DIR_ANAT}/${PIDSTR}_prep-denoise_${MODALITY}.nii.gz,${DIR_ANAT}/${PIDSTR}_prep-noise_${MODALITY}.nii.gz]
      # N4BiasFieldCorrection -d 3 -i ${IMG_RAW} -r 1 -s 4 -c [50x50x50x50,0.0] -b [50,3] -t [0.15,0.01,200] -o [${DIR_ANAT}/${PIDSTR}_prep-biasN4_${MODALITY}.nii.gz,${DIR_ANAT}/${PIDSTR}_biasField_${MODALITY}.nii.gz] -v 1

      # prepare to register allen to native ------------------------------------------
      mkdir -p ${DIR_ANAT}/native
      mkdir -p ${DIR_XFM}
      IMG_NATIVE=${DIR_ANAT}/native/${PIDSTR}_${MODALITY}-brain.nii.gz
      
      fslmaths ${DIR_ANAT}/${PIDSTR}_prep-denoise_${MODALITY}.nii.gz -mas ${MASK} ${IMG_NATIVE}
      IMG_RESAMP=${DIR_ANAT}/${PIDSTR}_prep-denoise_${ISOTROPIC_RES}mm_${MODALITY}.nii.gz

      3dresample -dxyz ${ISOTROPIC_RES} ${ISOTROPIC_RES} ${ISOTROPIC_RES} \
           -prefix  ${IMG_RESAMP} \
           -input ${IMG_NATIVE}
      
      3dresample -dxyz ${ISOTROPIC_RES} ${ISOTROPIC_RES} ${ISOTROPIC_RES} \
            -prefix ${MASK_RESAMP} \
            -input ${MASK}
      
      antsRegistration \
        --dimensionality 3 \
        --output ${DIR_XFM}/reg_template \
        --write-composite-transform 1 \
        --collapse-output-transforms 0 \
        --initialize-transforms-per-stage 1 \
        --initial-moving-transform [${FIXED},${IMG_RESAMP},1] \
        --transform Rigid[0.1] --metric Mattes[${FIXED},${IMG_RESAMP},1,32,Regular,0.25] --masks [${FIXED_MASK},${MASK_RESAMP}] --convergence [2000x2000x2000x2000x2000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
        --transform Affine[0.1] --metric Mattes[${FIXED},${IMG_RESAMP},1,32,Regular,0.25] --masks [${FIXED_MASK},${MASK_RESAMP}] --convergence [2000x2000x2000x2000x2000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
        --transform SyN[0.1,3,0] --metric CC[${FIXED},${IMG_RESAMP},1,4] --masks [${FIXED_MASK},${MASK_RESAMP}] --convergence [1000x500x250x100,1e-8,10] --smoothing-sigmas 3x2x1x0vox --shrink-factors 8x4x2x1 \
        --winsorize-image-intensities [0.005,0.995] \
        --float 1 \
        --verbose 1 \
        --random-seed 15754459
      
      antsApplyTransforms -d 3 -n MultiLabel \
        -i ${ATLAS_LABELS} \
        -o ${LABEL} \
        -t ${XFM_INVERSE} \
        -r ${IMG_RESAMP}
    else 
    # back propagate labels to native space ----------------------------------------
      echo "registration of ${PIDSTR} already done"
      mkdir -p ${DIR_ANAT}/label/HarvardOxford
      antsApplyTransforms -d 3 -n MultiLabel \
        -i ${ATLAS_LABELS} \
        -o ${LABEL} \
        -t ${XFM_INVERSE} \
        -r ${IMG_RESAMP}
    fi
    3dROIstats -mask ${LABEL} -nzvoxels ${IMG_RESAMP} >>${DIR_SUMMARY}/volumes.tsv
  done < ${rawdata}/${PID}/sessions.tsv
done < ${rawdata}/participants.tsv

