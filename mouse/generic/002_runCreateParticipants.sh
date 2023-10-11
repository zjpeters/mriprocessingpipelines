#!/bin/bash

rawdata=/media/zjpeters/Samsung_T5/willSWI/rawdata
matlab -nodisplay -nodesktop -nojvm -r "createParticipantsTsv('$rawdata'); exit;"
