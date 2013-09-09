Connect GoAnna with iPlant's Discovery Environment
==================================================

Usage
-----

```bash
python goanna_shim1.2.py --email EMAIL@SERVER.COM --program blastp --input_format fasta --file fileInDirectory --database AgBase --filter True --low_complexity False --expect 1 --word 3 --matrix --cost --desc_number --aln_number --check_all

perl goannashim.pl --PROGRAM blastp --EMAIL ericco92\@gmail.com --file_type fasta --ID_LIST myBov.fa --DATABASE AgBase  --no_iea 1 --EXP EXP --NR NR --ISS ISS --EXPECT 10 --WORD_SIZE 3 --GAPCOST Existence=11, Extension=1 --DESCRIPTIONS 3 --ALIGNMENTS 3 --EXP EXP --bypass_prg_check 0 --error 0 
```

Install
-------

Use server http://acan.iplantcollaborative.org.

```
cd to /usr/local3/bin
git clone https://github.com/mwvaughn/goanna-connect.git
cd goanna-connect
chmod a+rx goannashim.pl
~/register_component/register_batch.sh goannashim.json
```

Integrate with DE
-----------------

`goannashim.json` is the metadata file to integrate this tool with the DE (?).