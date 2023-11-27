#!/bin/bash

# Limit NF driver to 4 GB memory
export NXF_OPTS="-Xms500M -Xmx4G"

##########################
# REQUIRED INPUT ARGUMENTS
##########################
source ~/.research_config
rd7_data_dir=$LOCAL_REPLOGLE_2022_DATA_DIR"/processed/rd7/small/"
# response ODM
response_odm_fp=$rd7_data_dir"gene.odm"
# grna ODM
grna_odm_fp=$rd7_data_dir"grna.odm"
# sceptre object
sceptre_object=$rd7_data_dir"sceptre_object.rds"

###################
# OUTPUT DIRECTORY:
##################
output_dir="~/rd7_pipeline_outputs"

###############
# OPTIONAL ARGS
###############

#################
# Invoke pipeline
#################
nextflow run ../main.nf \
 --response_odm_fp response_odm_fp \
 --grna_odm_fp grna_odm_fp
 --sceptre_object sceptre_object
 