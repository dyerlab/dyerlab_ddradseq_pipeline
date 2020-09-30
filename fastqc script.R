#I tend to use camel case for variable names, if you prefer underscores 
#between words or some other system please let me know.




###Install fastqcr if not already installed###

# install.packages("fastqcr")

###Set working directory to fastq file location###

# setwd("D:/BNFO 508/data")



library("fastqcr")

###Edit fastq and fastqc results directories to match the file directories 
#you are using in this specific circumstance.

fastqDir <- "D:/BNFO 508/data/PROW Raw Reads"
qcDir <- "D:/BNFO 508/data/PROW fastqc Results"

fastqc(fq.dir = fastqDir,
       qc.dir = qcDir,
       threads = 1)

#### ^^^ You'll get an error on Windows machines from the above script 
#if you are not running R on a Linux subsystem, you can get around this
#by enabling use of your Linux subsystem on Windows 10 and above machines,
#and installing Ubuntu, installing R in Ubuntu, and running this script 
#on R in Ubuntu.  If you are on a Mac OSX or Linux machine then the above 
#script should work.  Also I'm aware this pipeline will be run on a cluster
#that is likely a Linux system, I am on a Windows machine so this is more
#for the purposes of checking to see if the script actually works.



###Enter the below script into Ubuntu to install R to your Windows subsystem.

###Install APT and update packages for Ubuntu, APT is a package manager that
###allows you to install software like R to Ubuntu.

# sudo apt update
# sudo apt install emacs unzip

#enter Y to continue

# Y



###Install R

#Still working on figuring this out, you can only install up to R 3.5 on Ubuntu and
#I'm not sure if the fastqcr package will run on 3.5