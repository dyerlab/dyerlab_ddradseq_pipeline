#! /bin/bash
## $1= PROW_reads
## $2 = /gpfs_fs/hohensteinta/PROW_reads;
######################################################                                                                         
#  execute script in set directory                                                                                         
#$ -wd /gpfs_fs/hohensteinta/PROW_reads                                                                                                                       
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


#for f in /gpfs_fs/hohensteinta/PROW_reads/raw/*fastq;
#do 
sample="$(echo $2 | cut -d '/' -f 5,5 | cut -d '.' -f 1,1)"
echo $sample
python fix_seqs.py $2 ./barcodes/PROW_barcodes '/gpfs_fs/hohensteinta/PROW_reads/'$1'/raw/'$sample'_f.fastq'
echo "Done filtering $sample raw reads $(date)"


