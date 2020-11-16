#!/usr/bin/env bash
######################################################
# qsub_test.sh
# Function: Report various environmental variables
# Usage: qsub qsub_test.sh 
######################################################
#  execute script in current directory
#$ -cwd
#  want any .e/.o stuff to show up here too
#$ -e ./
#$ -o ./
#  shell for qsub to use:
#$ -S /bin/bash
#  label for the job; displayed by qstat
#$ -N qsub_test

# examples which are not enabled by default:
# only run on a node with given minimum memory free

##  #$ -l mem_free=33G

# kill this jobs if its memory usage exceeds this limit

##  #$ -l h_vmem=50G

# submit an smp job which needs 4 cpu slots

##  #$ -pe smp_2 4

# activate email notification and send to given address
# use the following after -m to indicate when to notify
# 'b'     Mail is sent at the beginning of the job.
# 'e'     Mail is sent at the end of the job.
# 'a'     Mail is sent when the job is aborted or rescheduled.
# 's'     Mail is sent when the job is suspended.
# 'n'     No mail is sent.

## #$ -m beas -M user@vcu.edu

# To run on a selected node use:
# qsub -q all.q@godel28 /usr/global/qsub_test.sh

######################################################

# Append environmental varibles required to run program
# Examples:
# export PATH=/usr/local/foo/bin:${PATH}
# source /usr/local/bar/enable_bar.sh

######################################################

source /gpfs_fs/hohensteinta/bin/FastQC/fastqcCustomSettings.sh
 
PROGRAM=
 
START=$(date +%s)
NSTART=$(date +%s.%N)

# write out some job info

echo "hostname: "
/bin/hostname

echo "os: "
cat /etc/system-release

echo "kernel: "
uname -a

echo "id: "
/usr/bin/id

echo "memory usage: "
/usr/bin/free

echo Running on hosts $NHOSTS
echo NSLOTS is $NSLOTS
echo "Machines:"
cat $TMPDIR/machines
echo Time is $(date)
echo Directory is $(pwd)
echo Path is $PATH
echo Ld Library Path is $LD_LIBRARY_PATH

echo ""
echo "Gridengine variables" 
echo 

echo "Hostname: ${HOSTNAME}"
echo "N Hosts:  ${NHOSTS}"
echo "N Slots:  ${NSLOTS}"
echo "N Queues: ${NQUEUES}"
echo "Job ID:   ${JOB_ID}"
echo "Job Name: ${JOB_NAME}"

printf "\n"
printf "%s=%s \t %s \n" "ARC" ${ARC} "The architecture name of the node on which the job is running."
printf "%s=%s \t %s \n" "SGE_ROOT" ${SGE_ROOT} "The root directory of the grid engine system."
printf "%s=%s \t %s \n" "SGE_BINARY_PATH" ${SGE_BINARY_PATH} "The directory in which the grid engine system binaries are installed."
printf "%s=%s \t %s \n" "SGE_CELL" ${SGE_CELL} "The cell in which the job runs."
printf "%s=%s \t %s \n" "SGE_JOB_SPOOL_DIR" ${SGE_JOB_SPOOL_DIR} "The directory used by sge_shepherd to store job-related data while the job runs."

printf "%s=%s \t %s \n" "SGE_O_HOME" ${SGE_O_HOME} "The path to the home directory of the job owner on the host from which the job was submitted."
printf "%s=%s \t %s \n" "SGE_O_HOST" ${SGE_O_HOST} "The host from which the job was submitted."
printf "%s=%s \t %s \n" "SGE_O_LOGNAME" ${SGE_O_LOGNAME} "The login name of the job owner on the host from which the job was submitted."
printf "%s=%s \t %s \n" "SGE_O_MAIL" ${SGE_O_MAIL} "The content of the MAIL environment variable in the context of the job submission command."
printf "%s=%s \t %s \n" "SGE_O_PATH" ${SGE_O_PATH} "The content of the PATH environment variable in the context of the job submission command."

printf "%s=%s \t %s \n" "SGE_O_SHELL" ${SGE_O_SHELL} "The content of the SHELL environment variable in the context of the job submission command."
printf "%s=%s \t %s \n" "SGE_O_TZ"    ${SGE_O_TZ}    "The content of the TZ environment variable in the context of the job submission command."
printf "%s=%s \t %s \n" "SGE_O_WORKDIR" ${SGE_O_WORKDIR} "The working directory of the job submission command."
printf "%s=%s \t %s \n" "SGE_CKPT_ENV"  ${SGE_CKPT_ENV}  "The checkpointing environment under which a checkpointing job runs. The checkpointing environment is selected with the qsub -ckpt command."
printf "%s=%s \t %s \n" "SGE_CKPT_DIR"  ${SGE_CKPT_DIR}  "The path ckpt_dir of the checkpoint interface. Set only for checkpointing jobs. For more information, see the checkpoint(5) man page."

 


printf "%s=%s \t %s \n" "SHELL" ${SHELL} "The user's login shell as taken from the passwd file. This is not necessarily the shell that is used for the job."
printf "%s=%s \t %s \n" "TMPDIR" ${TMPDIR} "The absolute path to the job's temporary working directory."
printf "%s=%s \t %s \n" "TMP" ${TMP}    "The same as TMPDIR. This variable is provided for compatibility with NQS."
printf "%s=%s \t %s \n" "TZ" ${TZ}    "The time zone variable imported from sge_execd, if set."
printf "%s=%s \t %s \n" "USER" ${USER} "The user's login name as taken from the passwd file."
printf "\n"


#When a job runs, several variables are preset into the job's environment.

# ARC – The architecture name of the node on which the job is running. The name is compiled into the sge_execd binary.
# SGE_ROOT – The root directory of the grid engine system as set for sge_execd before startup, or the default /usr/SGE directory.
#SGE_BINARY_PATH – The directory in which the grid engine system binaries are installed.
#SGE_CELL – The cell in which the job runs.
#SGE_JOB_SPOOL_DIR – The directory used by sge_shepherd to store job-related data while the job runs.

#SGE_O_HOME – The path to the home directory of the job owner on the host from which the job was submitted.
#SGE_O_HOST – The host from which the job was submitted.
#SGE_O_LOGNAME – The login name of the job owner on the host from which the job was submitted.
#SGE_O_MAIL – The content of the MAIL environment variable in the context of the job submission command.
#SGE_O_PATH – The content of the PATH environment variable in the context of the job submission command.

#SGE_O_SHELL – The content of the SHELL environment variable in the context of the job submission command.
#SGE_O_TZ – The content of the TZ environment variable in the context of the job submission command.
#SGE_O_WORKDIR – The working directory of the job submission command.
#SGE_CKPT_ENV – The checkpointing environment under which a checkpointing job runs. The checkpointing environment is selected with the qsub -ckpt command.
#SGE_CKPT_DIR – The path ckpt_dir of the checkpoint interface. Set only for checkpointing jobs. For more information, see the checkpoint(5) man page.

#SGE_STDERR_PATH – The path name of the file to which the standard error stream of the job is diverted. This file is commonly used for enhancing the output with error messages from prolog, epilog, parallel environment start and stop scripts, or checkpointing scripts.
#SGE_STDOUT_PATH – The path name of the file to which the standard output stream of the job is diverted. This file is commonly used for enhancing the output with messages from prolog, epilog, parallel environment start and stop scripts, or checkpointing scripts.
#SGE_TASK_ID – The task identifier in the array job represented by this task.
#ENVIRONMENT – Always set to BATCH. This variable indicates that the script is run in batch mode.
#HOME – The user's home directory path as taken from the passwd file.

#HOSTNAME – The host name of the node on which the job is running.
#JOB_ID – A unique identifier assigned by the sge_qmaster daemon when the job was submitted. The job ID is a decimal integer from 1 through 9,999,999.
#JOB_NAME – The job name, which is built from the file name provided with the qsub command, a period, and the digits of the job ID. You can override this default with qsub -N.
#LOGNAME – The user's login name as taken from the passwd file.
#NHOSTS – The number of hosts in use by a parallel job.

#NQUEUES – The number of queues that are allocated for the job. This number is always 1 for serial jobs.
#NSLOTS – The number of queue slots in use by a parallel job.
#PATH – A default shell search path of: /usr/local/bin:/usr/ucb:/bin:/usr/bin.
#PE – The parallel environment under which the job runs. This variable is for parallel jobs only.
#PE_HOSTFILE – The path of a file that contains the definition of the virtual parallel machine that is assigned to a parallel job by the grid engine system. This variable is used for parallel jobs only. See the description of the $pe_hostfile parameter in sge_pe for details on the format of this file.

#QUEUE – The name of the queue in which the job is running.
#REQUEST – The request name of the job. The name is either the job script file name or is explicitly assigned to the job by the qsub -N command.
#RESTARTED – Indicates whether a checkpointing job was restarted. If set to value 1, the job was interrupted at least once. The job is therefore restarted.
#SHELL – The user's login shell as taken from the passwd file.
#Note –
#SHELL is not necessarily the shell that is used for the job.
#TMPDIR – The absolute path to the job's temporary working directory.

#TMP – The same as TMPDIR. This variable is provided for compatibility with NQS.
#TZ – The time zone variable imported from sge_execd, if set.
#USER – The user's login name as taken from the passwd file.

echo "ulimit: " 
ulimit -a

# show java version.  Normally this goes to 
# stderr, this is redirected to stdout 

echo ""
echo "java version: "
which java
java -version 2>&1

echo ""
echo "javac version: "
which javac
javac -version 2>&1

echo ""
echo "python version: "
which python
python -V 2>&1

echo ""
echo "pip version: "
which pip 2>&1
pip --version

echo ""
echo "python modules: "
pip freeze

echo ""
echo "perl version: "
which perl
perl --version

echo ""
echo "R version: "
which R
R --version

echo ""
echo "gcc version: "
which gcc
gcc --version

echo ""
echo "shell environment: "
env
echo "#####################"

# uncomment the following if you want a delay before
# the script is run - helpful when debugging.
##time=20
##sleep $time
 
# $1 are all the parameters passed above
 
##$PROGRAM $1
 
END=$(date +%s)
NEND=$(date +%s.%N)
 
let TOTAL="${END} - ${START}"
DIFF=$(echo "${NEND} - ${NSTART}" | bc)
 
echo "Script took ${TOTAL} seconds"
echo "Script tool ${DIFF} Nanoseconds"

