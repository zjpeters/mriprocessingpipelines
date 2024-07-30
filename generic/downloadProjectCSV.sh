#!/bin/bash
if [ $# != 2 ] ; then
  echo "Usage: `basename $0` {XNAT_PROJECT} {sourcedata}"
  echo "Function will request your username and password in order"
  echo "to access XNAT repository"
  exit 0;
fi
# the following downloads the information about the data contained in the project. we'll use this to help populate participants.tsv
# XNAT_PROJECT=TNJ_MOUSE
XNAT_PROJECT=$1
sourcedata=$2
echo -n "Please enter XNAT username: "
read username
echo -n "Password: "
read -s password

UP="${username}:${password}"
experimentUrl="https://rpacs.iibi.uiowa.edu/xnat/data/projects/${XNAT_PROJECT}/experiments?format=csv"
curl -X GET -u ${UP} ${experimentUrl} --show-error > $sourcedata/${XNAT_PROJECT}.csv