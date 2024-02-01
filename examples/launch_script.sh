#!/bin/bash
# Limit NF driver to 4 GB memory
nextflow pull timothy-barry/sceptre-pipeline
export NXF_OPTS="-Xms500M -Xmx4G"

##########################
# REQUIRED INPUT ARGUMENTS
##########################
data_directory=$HOME"/sceptre_data/"
# sceptre object
sceptre_object_fp=$data_directory"sceptre_object.rds"
# response ODM
response_odm_fp=$data_directory"gene.odm"
# grna ODM
grna_odm_fp=$data_directory"grna.odm"

##################
# OUTPUT DIRECTORY
##################
output_directory=$HOME"/sceptre_outputs"

#################
# Invoke pipeline
#################
nextflow run timothy-barry/sceptre-pipeline -r main \
 --sceptre_object_fp $sceptre_object_fp \
 --response_odm_fp $response_odm_fp \
 --grna_odm_fp $grna_odm_fp \
 --output_directory $output_directory \
 --grna_assignment_method "mixture" \
 --pair_pod_size "200" \
 --grna_pod_size "10" \
 --trial
