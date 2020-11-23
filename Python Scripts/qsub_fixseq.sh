#! /bin/bash
## $1= name of desired library sequence data (ie; lib2)
## $2 = name of sample file ($f) for commanline for loop: for f in *fastq.gz;
######################################################                                                                         
#  execute script in current directory                                                                                         
#$ -cwd                                                                                                                        
#  want any .e/.o stuff to show up here too                                                                                   
##$ -e                                                                                                                     
##$ -o                                                                                                                        
#  join STDOUT and STDERR                                                                                                      
#$ -j y                                                                                                                        
#  shell for qsub to use:                                                                                                     
#$ -S /bin/bash                                                                                                                
# Use Environmental Path                                                                                                       
#$ -V                                                                                                                          
#  label for the job; displayed by qstat                                                                                       
#$ -N fix_seq                                                                                                                  
#$ -pe smp 20                                                                                                                  
 #$ -m beas -M desaixmg@mymail.vcu.edu
                                                                                         
#$ -l mem_free=102G                                                                                                            
###################################################### 


#for f in /home/desaixmg/novogene/*.fastq.gz;
#do 
sample="$(echo $2 | cut -d '/' -f 5,5 | cut -d '.' -f 1,1)"
echo $sample
python fix_seqs.py $2 ./rawseq/$1_barcode.txt '/home/desaixmg/novogene/rawseq/'$1'raw/fix_test/'$sample'_f.fastq'
echo "Done filtering $sample raw reads $(date)"


