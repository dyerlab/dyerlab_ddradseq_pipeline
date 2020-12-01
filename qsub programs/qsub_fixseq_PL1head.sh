#! /bin/bash
######################################################
#$ -cwd
#$ -j y
#$ -S /bin/bash
#$ -V
#$ -N fix_seq
#$ -pe smp 20
#$ -m beas -M hohensteinta@mymail.vcu.edu
#$ -l mem_free=102G
######################################################
python /gpfs_fs/hohensteinta/PROW_reads/test/raw/fix_seqs_PL1head.py
echo "Done filtering $sample raw reads $(date)"