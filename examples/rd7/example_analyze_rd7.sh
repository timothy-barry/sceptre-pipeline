#!/bin/bash

# Limit NF driver to 4 GB memory
export NXF_OPTS="-Xms500M -Xmx4G"

##########################
# REQUIRED INPUT ARGUMENTS
##########################
source ~/.research_config
rd7_data_dir=$LOCAL_REPLOGLE_2022_DATA_DIR"/processed/rd7/"
# sceptre object
sceptre_object_fp=$rd7_data_dir"sceptre_object.rds"
# response ODM
response_odm_fp=$rd7_data_dir"gene.odm"
# grna ODM
grna_odm_fp=$rd7_data_dir"grna.odm"

###################
# OUTPUT DIRECTORY:
###################
output_directory="/Users/timbarry/rd7_pipeline_outputs"

#################
# Invoke pipeline
#################
nextflow run ../../main.nf \
 --sceptre_object_fp $sceptre_object_fp \
 --response_odm_fp $response_odm_fp \
 --grna_odm_fp $grna_odm_fp \
 --output_directory $output_directory \
 --grna_assignment_method "mixture" \
 --probability_threshold "0.98" \
 --n_nonzero_trt_thresh "9" \
 --n_nonzero_cntrl_thresh "9" \
 --pair_pod_size "30" \
 --pipeline_stop "set_analysis_parameters"
 