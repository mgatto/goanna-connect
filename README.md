Connect GoAnna with iPlant's Discovery Environment
==================================================

Usage
-----

Version 2 validates all options, converts some into flags (no more --EXP EXP since its now just --EXP), and sets defaults for others based on the GoAnna form page.

```bash
perl goanna-client.pl --program blastp --email mgatto@iplantcollaborative.org --type fasta --file t/fixtures/myBov.fa --databases AgBase,9913 --no_iea --EXP --NR --ISS
```

Multiple databases up to three may be searched by separating them by commas.

To see all the scripts command line options, run `goanna-client.pl --help`.

Install
-------

```bash
git clone https://github.com/mgatto/goanna-connect.git
cd goanna-connect
chmod a+rx goanna-client.pl
```
