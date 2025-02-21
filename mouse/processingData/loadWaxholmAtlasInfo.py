#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Feb 19 06:57:22 2025

@author: zjpeters
"""
import os
import csv

atlasLocation = os.path.join('/media/zjpeters/Samsung_T5/mriprocessingpipelines/mouse/anat/templates/WHS_0.5_Labels_LHRH.csv')

# load atlas information for grey matter regions
atlasInfo={'label_id':[],
           'label_name':[],
           'tissue':[]}
with open(atlasLocation, 'r', newline='') as tsvfile:
    csvreader = csv.reader(tsvfile, delimiter=',')
    next(csvreader)
    for i, row in enumerate(csvreader):
        #only load gm regions
        # if row[2] =='gm':
        atlasInfo['label_id'].append(int(row[0]))
        atlasInfo['label_name'].append(row[1])
        atlasInfo['tissue'].append(row[2])
