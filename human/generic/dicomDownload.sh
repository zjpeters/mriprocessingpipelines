# for (( i=0; i<${#DATE_LS[@]}; i++ )); do
#   echo "DATE: " ${DATE_LS[${i}]}
#   URL="https://rpacs.iibi.uiowa.edu/xnat/data/projects/${XNAT_PROJECT}/experiments?format=csv"
#   curl -X GET -u ${UP} ${URL} -s --show-error \
#     | awk -F "\"*,\"*" '{ print $2"\t"$7 }' \
#     | grep "${DATE_LS[${i}]}" \
#     > ${DIR_SAVE}"/"${XNAT_PROJECT}_${DATE_LS[${i}]}".pids"

#   FNAME=${DIR_SAVE}"/"${XNAT_PROJECT}_${DATE_LS[${i}]}".pids"

#   if [[ -s ${FNAME} ]]; then
#     while read PID DT; do
#       URL="https://rpacs.iibi.uiowa.edu/xnat/data/experiments/${PID}/scans/ALL/files?format=zip"
#       curl -X GET -u $UP $URL --fail --silent --show-error \
#       > ${DIR_SAVE}"/pi-"${PI}"_project-"${PROJECT}"_"${PID}"_"${DT//[-:. ]}".zip"
#     done < ${DIR_SAVE}"/"${XNAT_PROJECT}_${DATE_LS[${i}]}".pids"
#     rm ${DIR_SAVE}"/"${XNAT_PROJECT}_${DATE_LS[${i}]}".pids"
#   else
#     rm ${DIR_SAVE}"/"${XNAT_PROJECT}_${DATE_LS[${i}]}".pids"
#   fi
# done

# the following downloads the information about the data contained in the project. we'll use this to help populate participants.tsv
XNAT_PROJECT=JM_GNC
UP= #"username:pw"
experimentUrl="https://rpacs.iibi.uiowa.edu/xnat/data/projects/${XNAT_PROJECT}/experiments?format=csv"
curl -X GET -u ${UP} ${experimentUrl} --show-error > /home/zjpeters/rdss_tnj/twiceExceptional/sourcedata/${XNAT_PROJECT}.csv



while IFS="," read accessOrder id project date xsiType label insertDate URI; do
    [ "$id" == ID ] && continue;  # skips the header
    if [ -f /home/zjpeters/rdss_tnj/twiceExceptional/sourcedata/${id}.zip ]; then
        echo "File has already been downloaded for ${id}"
        continue
    else
        imageDLUrl="https://rpacs.iibi.uiowa.edu/xnat"$URI"/scans/ALL/resources/DICOM/files?format=zip"
        curl -X GET -u ${UP} ${imageDLUrl} --show-error >  /home/zjpeters/rdss_tnj/twiceExceptional/sourcedata/${id}.zip
    fi
    # echo $imageDLUrl
done < /home/zjpeters/rdss_tnj/twiceExceptional/sourcedata/${XNAT_PROJECT}.csv
