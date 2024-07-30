#!/bin/bash
if [ $# != 3 ] ; then
  echo "Usage: `basename $0` {XNAT_PROJECT} {CSV} {sourcedata}"
  echo "Function will request your username and password in order"
  echo "to access XNAT repository"
  exit 0;
fi
# the following downloads the information about the data contained in the project. we'll use this to help populate participants.tsv
# XNAT_PROJECT=TNJ_MOUSE
XNAT_PROJECT=$1
csv=$2
sourcedata=$3
echo -n "Please enter XNAT username: "
read username
echo -n "Password: "
read -s password

UP="${username}:${password}"

# as is, this will download every image in the list, but changing the csv referenced in the line:
# done < ../sourcedata/${XNAT_PROJECT}.csv
# can be changed for a condensed option
while IFS="," read accessOrder id project date xsiType label insertDate URI; do
    [ "$id" == ID ] && continue;  # skips the header
    # if [ "$label" == "3G_237-20220517" ]; then
    if [ ! -f ${sourcedata}/${id}.zip ]; then
        imageDLUrl="https://rpacs.iibi.uiowa.edu/xnat"$URI"/scans/ALL/resources/DICOM/files?format=zip"
        curl -X GET -u ${UP} ${imageDLUrl} --show-error >  $sourcedata/${id}.zip
        unzip "$sourcedata/${id}.zip"
    else
        echo "File has already been downloaded for ${id}"
        continue
    fi
    # echo $imageDLUrl
done < "${csv}"
