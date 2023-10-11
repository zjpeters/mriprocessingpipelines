# Neuroimaging processing pipelines
## Steps used in all pipelines
- Organizing data into BIDS format, using the following 4 main folders:
    - `code` - contains all of the unique code used to process your data
    - `derivatives` - contains all of the outputs of your data processing, including registered images, transformations, etc.
    - `rawdata` - contains nifti files after dcm2nii conversion and other data that will be used as the input for your analysis, as well as identifying (but not patient identifying) files such as `participants.tsv` and `sessions.tsv` that make processing easier. Has a specific `subject/session` directory organizational format to make it easier to navigate and process data
    - `sourcedata` - contains original dicom or compressed data as downloaded from XNAT or other server. Doesn't have a specific organizational format since different scanners or servers may organize dicoms differently 
    - more about this can be found at the BIDS website linked below
- Convert from dicom to nifti using `dcm2niix`
- Registration to some template image using `flirt`, `fnirt` (FSL), or `antsRegistration` (ANTS)
    - Both linear and nonlinear registrations are typically used
- Creation of brain mask, either via automated pipeline `bet` (FSL, works for humans) or `RATS_MM` ("works" for rodents)
    - Mask creation can also be done by hand using tools such as `BrainSuite`
    - Can be created before or after image registration, depending the data requirements
## MRI processing pipeline
- Basic set of scripts to be used when processing DWI data
1. `generic/000_dicom_to_nifti.sh` - searches for dicom files within sourcedata folder and outputs them to the rawdata folder. may need to update `-f` option to get the filenames correct
2. `generic/001_organize_rawdata_folder.sh` - searches the rawdata folder using predefined identifiers for modality (T1, DTI_32_DIR, fMRI_REST_Run_1, these will need updated) and moves the data into the correct BIDS defined folder (anat, dwi, func) 
3. `generic/002_runCreateParticipants.sh` - uses the matlab script `createParticipantsTsv.m` to generate a participants.tsv file within the rawdata folder along with a sessions.tsv within each subject folder
## DWI processing steps
4. `dwi/003_nonlinearDistortionCorrection.sh` - uses a t2w anatomical image (chosen because of intensity similarity) to correct for distortion as a result of the spin echo as well as run BET and DTIfit

## Anat/structural processing steps

# Useful links
[Brain Imaging Data Structure (BIDS)](https://bids.neuroimaging.io/)

[FMRIB Software Library (FSL)](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/)

[Analysis of Functional Neuro Images (AFNI)](https://afni.nimh.nih.gov/)

[Advanced Normalization Tools (ANTs)](http://stnava.github.io/ANTs/)

[The Allen Software Development Kit (SDK)](https://allensdk.readthedocs.io/en/latest/)