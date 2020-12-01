#! /bin/bash
## $1= /raw
## $2 = /barcodes;
######################################################                                                                         
#  execute script in current working directory                                                                                         
#$ -cwd                                                                                                                       
#  want any .e/.o stuff to show up here too                                                                                   
#$ -e fixSeqErr                                                                                                                    
#$ -o fixSeqOut                                                                                                                       
#  join STDOUT and STDERR                                                                                                      
#$ -j y                                                                                                                        
#  shell for qsub to use:                                                                                                     
#$ -S /bin/bash                                                                                                                
# Use Environmental Path                                                                                                       
#$ -V                                                                                                                          
#  label for the job; displayed by qstat                                                                                       
#$ -N fix_seq                                                                                                                  
#$ -pe smp 20                                                                                                                  
 #$ -m beas -M hohensteinta@mymail.vcu.edu
                                                                                         
#$ -l mem_free=102G                                                                                                            
###################################################### 


#for f in /gpfs_fs/hohensteinta/PROW_reads/test/raw/*.fastq;
#do 
sample="$(echo $2 | cut -d '/' -f 5,5 | cut -d '.' -f 1,1)"
echo $sample
python3 ~/pythonPrograms/fix_seqs_Tyler.py $2 ./barcodes/barcodes ''$1'/'$sample'_f.fastq'
echo "Done filtering $sample raw reads $(date)"


