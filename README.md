# Neuroimaging processing pipelines
## Folder descriptions
- `generic` - contains scripts that can be universally used for human and animal imaging datasets
- `human` - scripts related to human analysis, prioritizing 7T based analysis
- `mouse` - scripts for processing mouse datasets, typically adjusting for sizing differences between subjects and scanners as compared to human

## Overview of steps used in all pipelines
- Organizing data into BIDS format, using the following 4 main folders:
    - `code` - contains all of the unique code used to process your data
    - `derivatives` - contains all of the outputs of your data processing, including registered images, transformations, etc.
    - `rawdata` - contains nifti files after dcm2nii conversion and other data that will be used as the input for your analysis, as well as identifying (but not patient identifying) files such as `participants.tsv` and `sessions.tsv` that make processing easier. Has a specific `subject/session` directory organizational format to make it easier to navigate and process data
    - `sourcedata` - contains original dicom or compressed data as downloaded from XNAT or other server. Doesn't have a specific organizational format since different scanners or servers may organize dicoms differently 
    - more about this can be found at the BIDS website linked below
- Convert from `sourcedata` dicoms to `rawdata` niftis using `dcm2niix`
- Registration to some template image using `flirt`, `fnirt` (FSL), or `antsRegistration` (ANTS)
    - Both linear and nonlinear registrations are typically used
- Creation of brain mask, either via automated pipeline `bet` (FSL, works for humans) or `RATS_MM` ("works" for rodents)
    - Mask creation can also be done by hand using tools such as `BrainSuite`
    - Can be created before or after image registration, depending the data requirements
## MRI processing pipeline
- Basic set of scripts to be used when processing MRI data
1. `generic/dicomDownload.sh` - will download all data from the given XNAT project and store it in the given `sourcedata` location
2. `generic/dicomToNiftiOrganize.sh` - searches for dicom files within the given `sourcedata` folder and outputs them to the given `rawdata` folder using BIDS format. *may need to update `-f` option to get the filenames correct, as well as add to modalities in the case functionality*
3. `generic/createParticipantsTsv.sh` - uses the naming of the folders within `rawdata` to generate a participants.tsv file within the rawdata folder and a sessions.tsv within each subject folder
## DWI processing steps
4. `dwi/003_nonlinearDistortionCorrection.sh` - uses a t2w anatomical image (chosen because of intensity similarity) to correct for distortion as a result of the spin echo as well as run BET and DTIfit

## Anat/structural processing steps

# Useful links
[Brain Imaging Data Structure (BIDS)](https://bids.neuroimaging.io/)

[FMRIB Software Library (FSL)](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/)

[Analysis of Functional Neuro Images (AFNI)](https://afni.nimh.nih.gov/)

[Advanced Normalization Tools (ANTs)](http://stnava.github.io/ANTs/)

[The Allen Software Development Kit (SDK)](https://allensdk.readthedocs.io/en/latest/)