#!/usr/bin/env bash
########################

#$ -wd /gpfs_fs/hohensteinta/PROW_reads/raw
#$ -w e
#$ -e fastqcError
#$ -o fastqcOutput
#$ -m ea
#$ -M hohensteinta@mymail.vcu.edu
#$ -N PROW_fastqc
#$ -S /bin/bash

source /gpfs_fs/hohensteinta/bin/FastQC/fastqcCustomSettings.sh
PROGRAM=fastqc

$PROGRAM $1