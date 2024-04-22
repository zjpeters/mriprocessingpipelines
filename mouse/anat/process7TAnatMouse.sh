#!/bin/bash
###################################################################################
# need to update it so that the user inputs the dir_project
###################################################################################

DIR_PROJECT=/Users/yfilali/Stress/Vulnerability_EF_Experiment/fMRI

if [ -f "${DIR_PROJECT}/derivatives/volume_cohort2_VEF.tsv" ]; then
  rm "${DIR_PROJECT}/derivatives/volume_cohort2_VEF.tsv"
fi
touch "${DIR_PROJECT}/derivatives/volume_cohort2_VEF.tsv"

while read PID SID; do
  [ "$PID" == participant_id ] && continue;  # skips the header

  PIDSTR=${PID}_${SID}
  DIRPID=${PID}/${SID}

  DIR_PREP=${DIR_PROJECT}/derivatives/inc/prep/${DIRPID}/anat
  DIR_ANAT=${DIR_PROJECT}/derivatives/inc/anat
  DIR_MASK=${DIR_ANAT}/mask
  DIR_XFM=${DIR_PROJECT}/derivatives/inc/xfm/${DIRPID}

  LABEL=${DIR_ANAT}/label/allen/${PIDSTR}_label-allen.nii.gz

  XFM4=${DIR_XFM}/reg_Allen0Warp.nii.gz
  XFM3=${DIR_XFM}/reg_Allen0InverseWarp.nii.gz

  XFM=${DIR_XFM}/reg_AllenComposite.h5
  XFM_INVERSE=${DIR_XFM}/reg_AllenInverseComposite.h5
  IMG_NATIVE=${DIR_ANAT}/native/${PIDSTR}_T2w-brain.nii.gz
  if [ ! -f ${XFM} ]; then
    echo "beginning registration ${PIDSTR}"

    mkdir -p ${DIR_PREP}
    mkdir -p ${DIR_MASK}

    # gather raw images and remove extraneous BIDS flags ---------------------------
    ## rewrite to include only run flag
    ## set image list (order of priority determined by MODLS and BIDS flags
    IMG_RAW=${DIR_PROJECT}/derivatives/prep/${DIRPID}/${PIDSTR}_T2w.nii.gz
    IMG=${DIR_PREP}/${PIDSTR}_T2w.nii.gz
    cp ${IMG_RAW} ${IMG}
    O_MASK=${DIR_PROJECT}/derivatives/anat/mask/${PIDSTR}_mask-brain.nii.gz
    MASK=${DIR_MASK}/${PIDSTR}_mask-brain.nii.gz
    cp ${O_MASK} ${MASK}

    # bias correction --------------------------------------------------------------
    N4BiasFieldCorrection -d 3 -i ${IMG} -x ${MASK} -r 1 -s 4 -c [50x50x50x50,0.0] -b [6,3] -t [0.15,0.01,200] -o [${DIR_PREP}/${PIDSTR}_prep-biasN4_T2w.nii.gz,${DIR_PREP}/${PIDSTR}_biasField_T2w.nii.gz] -v 1
    # denoise ----------------------------------------------------------------------
    DenoiseImage -d 3 -n Rician -s 1 -p 1 -r 2 -v 1 -x ${MASK} -i ${DIR_PREP}/${PIDSTR}_prep-biasN4_T2w.nii.gz -o [${DIR_PREP}/${PIDSTR}_prep-denoise_T2w.nii.gz,${DIR_PREP}/${PIDSTR}_prep-noise_T2w.nii.gz]

    # prepare to register allen to native ------------------------------------------
    mkdir -p ${DIR_ANAT}/native
    ## this originally had it copying the uncorrected image to use, which doesn't make sense
    # IMG_NATIVE=${DIR_ANAT}/native/${PIDSTR}_T2w.nii.gz
    # cp ${IMG} ${IMG_NATIVE}
    # cp ${DIR_PREP}/${PIDSTR}_T2w.png ${DIR_ANAT}/native/${PIDSTR}_T2w.png

    fslmaths ${DIR_PREP}/${PIDSTR}_prep-denoise_T2w.nii.gz -mas ${MASK} ${IMG_NATIVE}
    FIXED=${DIR_PROJECT}/template/P56_Atlas_downsample2.nii.gz
    ## need to check that this is a mask and not just a skull stripped brain
    FIXED_MASK=${DIR_PROJECT}/template/P56_brain.nii.gz

    mkdir -p ${DIR_ANAT}/reg_Allen

    ## this should be the same as the previous coregistrationChef
    ## note: I've set it to output to the ${DIR_XFM} folder, which is slightly different
    antsRegistration \
      --dimensionality 3 \
      --output ${DIR_XFM}/reg_Allen \
      --write-composite-transform 1 \
      --collapse-output-transforms 0 \
      --initialize-transforms-per-stage 1 \
      --transform Rigid[0.1] --metric Mattes[${FIXED},${IMG_NATIVE},1,32,Regular,0.25] --masks [${FIXED_MASK},${MASK}] --convergence [2000x2000x2000x2000x2000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
      --transform Affine[0.1] --metric Mattes[${FIXED},${IMG_NATIVE},1,32,Regular,0.25] --masks [${FIXED_MASK},${MASK}] --convergence [2000x2000x2000x2000x2000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
      --transform SyN[0.1,3,0] --metric CC[${FIXED},${IMG_NATIVE},1,4] --masks [${FIXED_MASK},${MASK}] --convergence [100x70x50x20,1e-6,10] --smoothing-sigmas 3x2x1x0vox --shrink-factors 8x4x2x1 \
      --winsorize-image-intensities [0.005,0.995] \
      --float 1 \
      --verbose 1 \
      --random-seed 15754459
    mkdir -p ${DIR_ANAT}/label/allen
    antsApplyTransforms -d 3 -n MultiLabel \
      -i ${DIR_PROJECT}/template/P56_Annotation_downsample2.nii.gz \
      -o ${DIR_ANAT}/label/allen/${PIDSTR}_label-allen.nii.gz \
      -t ${XFM_INVERSE} \
      -r ${IMG_NATIVE}
  else 
  ## Haven't updated this bit yet, since I want to be able to see the naming of above
  # back propagate labels to native space ----------------------------------------
  # XFM4="[${DIR_XFM}/${PIDSTR}_mod-T2w-brain_from-native_to-allen_xfm-affine.mat,1]"
  # XFM3=${DIR_XFM}/${PIDSTR}_mod-T2w-brain_from-native_to-allen_xfm-syn+inverse.nii.gz
    echo "registration of ${PIDSTR} already done"
    mkdir -p ${DIR_ANAT}/label/allen
    antsApplyTransforms -d 3 -n MultiLabel \
      -i ${DIR_PROJECT}/template/P56_Annotation_downsample2.nii.gz \
      -o ${LABEL} \
      -t ${XFM_INVERSE} \
      -r ${IMG_NATIVE}
   fi
   3dROIstats -mask ${LABEL} -nzvoxels ${IMG_NATIVE} >>${DIR_PROJECT}/summary/volume_cohort2_VEF.tsv

done < ${DIR_PROJECT}/rawdata/participants.tsv


#  summarize3D \
#    --label ${LABEL} \
#    --value ${IMG_NATIVE} \
#    --stats volume

# ANTs Coregistration Call -------------------------------------------------------

# antsRegistration a
# --dimensionality 3 
# --output /Shared/inc_scratch/sjcochran_20240314T100618361952082/xfm_ 
# --write-composite-transform 0 
# --collapse-output-transforms 1 
# --initialize-transforms-per-stage 0 
# --initial-moving-transform /Shared/sjcochran_scratch/yassine_mouse/derivatives/inc/xfm/sub-VEF1/ses-20210824/sub-VEF1_ses-20210824_init-xfm.txt 
# --transform Rigid[0.1] 
# --metric Mattes[/Shared/sjcochran_scratch/yassine_mouse/template/P56_Atlas_downsample2.nii.gz,/Shared/sjcochran_scratch/yassine_mouse/derivatives/inc/anat/native/sub-VEF1_ses-20210824_T2w-brain.nii.gz,1,32,Regular,0.25] 
# --masks [/Shared/inc_scratch/sjcochran_20240314T100618361952082/FIXED_MASK_0.nii.gz,/Shared/inc_scratch/sjcochran_20240314T100618361952082/MOVING_MASK_0.nii.gz] 
# --convergence [2000x2000x2000x2000x2000,1e-6,10] 
# --smoothing-sigmas 4x3x2x1x0vox 
# --shrink-factors 8x8x4x2x1 
# --transform Affine[0.1] 
# --metric Mattes[/Shared/sjcochran_scratch/yassine_mouse/template/P56_Atlas_downsample2.nii.gz,/Shared/sjcochran_scratch/yassine_mouse/derivatives/inc/anat/native/sub-VEF1_ses-20210824_T2w-brain.nii.gz,1,32,Regular,0.25] 
# --masks [/Shared/inc_scratch/sjcochran_20240314T100618361952082/FIXED_MASK_0.nii.gz,/Shared/inc_scratch/sjcochran_20240314T100618361952082/MOVING_MASK_0.nii.gz] 
# --convergence [2000x2000x2000x2000x2000,1e-6,10] 
# --smoothing-sigmas 4x3x2x1x0vox 
# --shrink-factors 8x8x4x2x1 
# --transform SyN[0.1,3,0] 
# --metric CC[/Shared/sjcochran_scratch/yassine_mouse/template/P56_Atlas_downsample2.nii.gz,/Shared/sjcochran_scratch/yassine_mouse/derivatives/inc/anat/native/sub-VEF1_ses-20210824_T2w-brain.nii.gz,1,4] 
# --masks [/Shared/inc_scratch/sjcochran_20240314T100618361952082/FIXED_MASK_0.nii.gz,/Shared/inc_scratch/sjcochran_20240314T100618361952082/MOVING_MASK_0.nii.gz] 
# --convergence [100x70x50x20,1e-6,10] 
# --smoothing-sigmas 3x2x1x0vox 
# --shrink-factors 8x4x2x1 
# --use-histogram-matching 0 
# --winsorize-image-intensities [0.005,0.995] 
# --float 1 
# --verbose 1 
# --random-seed 15754459






