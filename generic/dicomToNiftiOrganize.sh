#!/bin/bash
# Requirements: dcm2niix, afni
helpRequest() {
    [ "$#" -le "1" ] || [ "$1" = '-h' ] || [ "$1" = '-help' ]
}
if helpRequest "$@"; then
    echo "Usage: `basename $0` {sourcedata} {rawdata}"
    echo "Function search for dicom files inside of sourcedata and export nifti files into rawdata."
    echo "If no rawdata folder is given, function will default to folder parallel to sourcedata"
    exit 0;
fi
# removes case sensitivity for folder assignment
shopt -s nocasematch

dicomToNiftiOrganize() {
    sourcedata="${1}"
    rawdata="${2:-${sourcedata//sourcedata/rawdata}}"
    for folder in "$sourcedata"/*; do
        if [ -d "$folder" ]; then
            cd "$folder"
            # look through the folder to find the first dicom file and collect subject and session info
            dcmFilename=$(find -type f -name "*.dcm" | head -n 1)
            # the following lines use dicom_hdr from afni with grep to find names and dates
            subID=$(dicom_hdr "$dcmFilename" | grep "0010 0010")
            subID=${subID//*Name\/\//sub-}
            sesDate=$(dicom_hdr "$dcmFilename" | grep "0008 0023")
            sesDate=${sesDate//*Date\/\//}
            sesTime=$(dicom_hdr "$dcmFilename" | grep "0008 0030")
            sesTime=${sesTime//*Time\/\//}
            sesID=ses-${sesDate}${sesTime}
            # checks whether data has already been converted for this particular session
            if [ -d "${rawdata}/${subID}/${sesID}" ]; then
                echo "Files have already been converted for ${subID}_${sesID}, check:\
                ${rawdata}/${subID}/${sesID}"
            elif [ "${sesID}" == "ses-" ]; then
                continue 
            else
                echo "Converting dicom to nifti for ${subID} ${sesID}"
                echo "dcm2niix -d 9 -b y -z y -i y -f sub-%n_ses-%t_%d ${folder}/scans/ ${sourcedata}"
                dcm2niix -d 9 -b y -z y -i y -f sub-%n_ses-%t_%d .
                # begin formatting for BIDS
                mkdir -p "$rawdata/$subID/$sesID/{anat,dwi,func,other}"
                for jsonFile in *.json; do
                    if [ -f $jsonFile ]; then
                        modality=${jsonFile##*${sesID}}
                        modality=${modality//.json/}
                        case $modality in
                            *fiesta* | *mprage* | *t1* | *t2* ) mv ${jsonFile//.json/}* "$rawdata/$subID/$sesID/anat/" ;;
                            *fmri* | *func* | *rest* ) mv ${jsonFile//.json/}* "$rawdata/$subID/$sesID/func/" ;;
                            *dwi* | *dti* | *32dir* | *32_dir* ) mv ${jsonFile//.json/}* "$rawdata/$subID/$sesID/dwi/" ;;
                            * ) mv ${jsonFile//.json/}* "$rawdata/$subID/$sesID/other"
                        esac
                    fi
                done                
            fi
        fi
    done
} 
dicomToNiftiOrganize "$@"


##############################################################################
# You will likely need to adjust details of this script to account for your naming structure
# The dcm2niix line can be adjusted for various options
# dcm2niix options used are 
# -d: directory search depth of 9
# -b: bids formatted json sidecar
# -i: ignore localizer images
# -f: filename structure will use "sub-SUBJECTNAME_ses-TIMEOFSCAN_MODALITY"
# -o: output converted niftis into rawdata folder
##############################################################################