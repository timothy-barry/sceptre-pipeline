#!/bin/bash

# Limit NF driver to 4 GB memory
export NXF_OPTS="-Xms500M -Xmx4G"

##########################
# REQUIRED INPUT ARGUMENTS
##########################
ex_dir="/Users/timbarry/sceptre_example/"
# sceptre object
sceptre_object_fp=$ex_dir"sceptre_object.rds"
# response ODM
response_odm_fp=$ex_dir"gene.odm"
# grna ODM
grna_odm_fp=$ex_dir"grna.odm"

###################
# OUTPUT DIRECTORY:
##################
output_directory="/Users/timbarry/sceptre_example/pipeline_outputs"

#################
# Invoke pipeline
#################
nextflow run ../../main.nf -resume \
 --sceptre_object_fp $sceptre_object_fp \
 --response_odm_fp $response_odm_fp \
 --grna_odm_fp $grna_odm_fp \
 --output_directory $output_directory \
 --grna_assignment_method "mixture" \
 --pair_pod_size "30" \
 --grna_pod_size "10" \
 --pipeline_stop "run_discovery_analysis"
 