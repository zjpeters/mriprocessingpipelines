#!/bin/bash
# uses AFNI, ANTs, FSL
if [ $# != 2 ] ; then
  echo "Usage: `basename $0` {subjectImage} {outputLocation}"
  echo "Processes functional MRI data using the selected information"
  exit 0;
fi
export fMRI=$1
derivatives=$2
optLoc=/Shared/pinc/sharedopt/apps
AFNIDIR=${optLoc}/afni/Linux/x86_64/22.3.07
ANTSDIR=${optLoc}/ants/Linux/x86_64/2.4.4/bin
FSLDIR=${optLoc}/fsl/Linux/x86_64/6.0.6.5/bin
. ${FSLDIR}/etc/fslconf/fsl.sh
PATH=${AFNIDIR}:${ANTSDIR}:${FSLDIR}/bin:${PATH}
export AFNIDIR ANTSDIR FSLDIR PATH
# setting static variables
template=$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz
#templateMask=$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask.nii.gz

filename=$(basename $fMRI)
participant_id=${filename%%_ses-*}
session_id=$(echo $filename | sed 's/^.*\(ses-.*_\).*$/\1/')
session_id=${session_id%%_*}
modality=$(basename $fMRI)
modality=${modality//${participant_id}_${session_id}_}
modality=${modality%%.nii.gz}
outputFolder=${derivatives}/${participant_id}
outputNameBase=${derivatives}/${participant_id}/${participant_id}_${session_id}_${modality}

outDir=$derivatives/${participant_id}/func
if [ ! -d $outDir ]; then
  mkdir -p $outDir
elif [ -f $outDir/${participant_id}_${session_id}_fMRI_Detrend.nii ]; then
  echo "Preprocessing has already been done"
  exit 0;
fi

# copied and updated from processMouseFmri
# starting with 2 runs, with 1 .nii.gz and 1 .json per run
################################################################
#              Regsiter the time series data                     #
################################################################
volRegImage=$outDir/${participant_id}_${session_id}_${modality}_volreg.nii
volRegData=$outDir/${participant_id}_${session_id}_${modality}_volreg.1D
reorient=$outDir/${participant_id}_${session_id}_${modality}_RPI.nii.gz
deoblique=$outDir/${participant_id}_${session_id}_${modality}_deoblique.nii.gz

echo $fMRI 
${AFNIDIR}/3dresample -orient rpi -overwrite -prefix ${reorient} -input $fMRI
${AFNIDIR}/3dWarp -deoblique -prefix ${deoblique} ${reorient}
${AFNIDIR}/3dvolreg -base 60 -prefix ${volRegImage} -1Dfile ${volRegData}  ${deoblique}
################################################################
#            Despike the data  - Write out Spikes              #
################################################################
despikeImage=$outDir/${participant_id}_${session_id}_${modality}_volreg_despike.nii
despikeData=$outDir/${participant_id}_${session_id}_${modality}_spikes.nii
${AFNIDIR}/3dDespike -ssave ${despikeData} -prefix ${despikeImage} ${volRegImage}
# if adding regressions, add HERE
################################################################
#          Smooth the time series data spatially               #
################################################################
volRegSmooth=$outDir/${participant_id}_${session_id}_${modality}_volreg_despike_smooth.nii
${AFNIDIR}/3dmerge -doall -prefix ${volRegSmooth} -1blur_fwhm 0.4 ${despikeImage}
# template=$FSLDIR/data/standard/MNI152_T1_0.5mm.nii.gz
################################################################
#          Align the EPI to the Anatomical Image               #
###############################################################
# Create a mean EPI to Drive Registration
meanEpiImage=$outDir/${participant_id}_${session_id}_${modality}_Mean.nii
meanEpiBrainImage=$outDir/${participant_id}_${session_id}_${modality}_Mean_Brain.nii
volRegSmoothMean=$outDir/${participant_id}_${session_id}_${modality}_volreg_despike_smooth_mean.nii
volRegSmoothMeanBrain=$outDir/${participant_id}_${session_id}_${modality}_volreg_despike_smooth_mean_brain.nii.gz
volRegCoreg=$outDir/${participant_id}_${session_id}_${modality}_volreg_despike_smooth_mean_coreg
volRegSmoothCoreg=$outDir/${participant_id}_${session_id}_${modality}_volreg_despike_smooth_coreg.nii
composite=$outDir/${participant_id}_${session_id}_${modality}_volreg_despike_smooth_mean_coregComposite.h5
${AFNIDIR}/3dTstat -mean -prefix ${volRegSmoothMean} ${volRegSmooth}
${FSLDIR}/bet ${volRegSmoothMean} ${volRegSmoothMeanBrain} -m -R
${ANTSDIR}/antsRegistration --dimensionality 3 --output ${volRegCoreg} --initial-moving-transform [${template},${volRegSmoothMeanBrain},1]  \
  --transform Rigid[0.1] --metric Mattes[${template}, ${volRegSmoothMeanBrain},1,32,Regular,0.25] --convergence [2000x2000x2000x2000x2000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
--transform Affine[0.1] --metric Mattes[${template},${volRegSmoothMeanBrain},1,32,Regular,0.25] --convergence [1000x1000x1000x1000x1000,1e-6,10] --smoothing-sigmas 4x3x2x1x0vox --shrink-factors 8x8x4x2x1 \
--use-histogram-matching 1 --verbose 1 --random-seed 13983981 --winsorize-image-intensities [0.005,0.995] --write-composite-transform 1

${ANTSDIR}/antsApplyTransforms -d 3 -n BSpline[3] -i ${volRegSmoothMeanBrain} -o ${volRegCoreg}.nii -t ${composite} -r ${template} -v
${ANTSDIR}/antsApplyTransforms -d 3 -e 3 -n BSpline[3] -i ${volRegSmooth} -o ${volRegSmoothCoreg} -t ${composite} -r ${template} -v

####### below uses freesurfer 
# Align Mean EPI to the Anatomical Image
anatBrainImage=$rawdata/${participant_id}/${session_id}/anat/${participant_id}_${session_id}_${anatModality}.nii.gz
epiMeanAlignAnat=$outDir/${participant_id}_${session_id}_fMRI_AlignMean.nii
epiAlignParams=$outDir/${participant_id}_${session_id}_fMRI_AlignAnatParams.1D
# 3dAllineate -base ${volRegCoreg} -input ${resampledVolRegSmoothBrain} -prefix ${epiMeanAlignAnat} -1Dparam_save ${epiAlignParams} -cost nmi -warp affine_general

# Apply Transform parameters to the time series data
epiAlignAnat=$outDir/${participant_id}_fMRI_Run_${session_id}_Epi2Anat.nii
# 3dAllineate -base ${volRegCoreg} -input ${volRegSmooth} -prefix ${epiAlignAnat} -1Dparam_apply ${epiAlignParams}
################################################################
#     Detrend the time series data before seed generation      #
################################################################
detrendImage=$outDir/${participant_id}_${session_id}_${modality}_Detrend.nii
${AFNIDIR}/3dDetrend -prefix ${detrendImage} -polort 3 ${volRegSmoothCoreg}