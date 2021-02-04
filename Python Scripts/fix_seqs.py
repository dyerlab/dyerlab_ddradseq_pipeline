#fix_seqs.py

from sys import argv
from re import search, sub
import gzip
def main():

  fastqfile = gzip.open(argv[1])
  barcodefile = open(argv[2],'r')
# except:
#  print 'Usage: python fix_seqs.py fastqfile.fq barcode.txt output.fastq'
 # quit()
  
  #mismatches_file = open(argv[4], 'w')
  fixed_seqfile = open(argv[3], 'w')
  
#hard code reverse compliment of ECORI
  ### THIS IS WRONG, notify Matthew DeSaix ###
  RC_ecori = 'CAATTC'
  ecori = 'GAATTG'

#read in barcodes. Store 
  barcode_dic = {}
  for line in barcodefile:
    line = line.strip().split('\t')
    barcode = line[0].upper()
    RC_barcode = reverseCompliment(barcode).upper()
    barcode_dic[RC_barcode] = barcode 
  
#read in fastq file
  reads = parse_fastq(fastqfile)
#outend=open('eol_barcodes.fasta','w') 
#grep for barcode at beginning, reverse compliment it. 
  for header, seq, baseQ in reads:
    header, seq, baseQ = header.rstrip(), seq.rstrip(), baseQ.rstrip()
    mismatches = 0
    for barcode in barcode_dic:
    #mm=str('N'+barcode[1:])
      if seq.startswith(barcode):
        seq = sub('^%s'%barcode, barcode_dic[barcode], seq)
        seq = sub('(?<=%s)%s'%(barcode_dic[barcode], RC_ecori), 
           ecori, seq)
        fixed_seqfile.write('%s\n%s\n%s\n%s\n'%(header, seq, '+', baseQ)) 
      elif seq.endswith(barcode):
        seq=sub('(?=%s)%s'%(barcode_dic[barcode], RC_ecori),'',seq)
        seq=sub('^%s'%barcode, '', seq)
        seq=str(barcode_dic[barcode]+ecori+seq)
      #seq = sub('^%s'%barcode, barcode_dic[barcode], seq)
      #seq = sub('(?=%s)%s'%(barcode_dic[barcode], RC_ecori),
      #   ecori, seq)
      #outend.write(str('>'+header+'\n'+seq+'\n'))
        fixed_seqfile.write('%s\n%s\n%s\n%s\n'%(header, seq, '+', baseQ))
      #Reverse compiment sequence
      #upstreamseq = str(barcode_dic[barcode]+ecori)
      #downstreamseq = seq.replace(upstreamseq, '')
      #RC_downstreamseq = reverseCompliment(downstreamseq)
      #seq = upstreamseq+RC_downstreamseq
      #fixed_seqfile.write('%s\n%s\n%s\n%s\n'%(header, seq, '+',
      #				 baseQ))
      
      else:
        mismatches += 1
      
  #if mismatches == len(barcode_dic):
    #mismatches_file.write(str('>'+header+'\n'+seq+'\n'))

#outend.close()

def reverseCompliment(seq):
  complementDict = {'A':'T', 'T':'A', 'G':'C', 'C':'G', 'N':'N',
                    'a':'t', 't':'a', 'g':'c', 'c':'g', 'n':'n'}
  result = ''
  for x in seq[::-1]:
    result += complementDict[x]
  return result  

def parse_fastq(fastqFile):
    '''
    Arg: File object containing a fastq file
    Returns: Generator object containing a tuple containing 
    header, seq, base quality
    '''
    i = 1
    header, seq, baseQ = None, [], []
    for line in fastqFile.readlines():
            if (line.startswith("@")) and (i%4 != 0):
                    if header: yield (header, ''.join(seq), ''.join(baseQ))
                    header, seq, baseQ = line, [], []
            if (i%4==2):
                    seq.append(line)
            if (i%4 == 0):
                    baseQ.append(line)               
            i += 1
    if header: yield (header, ''.join(seq), ''.join(baseQ))

def makefastqdict(fastq, noN=False): 
    '''
    Arg: Generator conaining header, seq, baseq info. 
    Returns: Dictionary key=header, value=seq
    Setting noN=True will return only sequences that do not contain N's
    '''
    dic = {}
    if noN:
        for header, seq, baseq in parse_fastq(fastq):
            if 'N' not in seq:
                dic[header.strip()] = seq.strip()
              
    else:
        for header, seq, baseq in parse_fastq(fastq):
            dic[header.strip()] = seq.strip()            
              
    return dic

main()
