#!/bin/bash
#PBS -j oe
#PBS -N tune_ampir
#PBS -l walltime=23:00:00
#PBS -l select=1:ncpus=40:mem=120gb

cd $PBS_O_WORKDIR
shopt -s expand_aliases
source /etc/profile.d/modules.sh
echo "Job identifier is $PBS_JOBID"
echo "Working directory is $PBS_O_WORKDIR"

module load R/3.6.1
Rscript tune_model.R outfile=../cache/tuned_legacy.rds train=../cache/featuresTrain_legacy.rds ncores=76
Rscript tune_model.R outfile=../cache/tuned_legacy_final.rds train=../cache/features_legacy.rds ncores=76
