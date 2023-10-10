# DWI processing pipeline
- Basic set of scripts to be used when processing DWI data
1. `000_dicom_to_nifti.sh` - searches for dicom files within sourcedata folder and outputs them to the rawdata folder. may need to update `-f` option to get the filenames correct
2. `001_organize_rawdata_folder.sh` - searches the rawdata folder using predefined identifiers for modality (T1, DTI_32_DIR, fMRI_REST_Run_1, these will need updated) and moves the data into the correct BIDS defined folder (anat, dwi, func) 
3. `002_runCreateParticipants.sh` - uses the matlab script `createParticipantsTsv.m` to generate a participants.tsv file within the rawdata folder along with a sessions.tsv within each subject folder
4. `003_nonlinearDistortionCorrection.sh` - uses a t2w anatomical image (chosen because of intensity similarity) to correct for distortion as a result of the spin echo as well as run BET and DTIfit
