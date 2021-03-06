# R package virDisco

The virDisco, short for virus detection and discovery, is a R package with uses many third party programs. Therefore, these programs must be installed on the computer. Further, many of these third party programs are based on Linux. Therefore, the virDisco package is more or less a Linux only R package. Still, it can be installed and used, but some functions will not work.

## Table of Contents
1. [Installation](#installation)
2. [Tutorial](#tutorial)
3. [Output files](#output-files)
4. [Setup NCBI GenBank database](#setup-ncbi-genbank-database)

## Installation

The development version from github:

```R
devtools::install_github("jkruppa/virDisco")
```

## Tutorial

The package has many dependencies, which must be installed first. Some programes migth be in the load path, others might not. To make it more relaiable for the user, all programs must be specified first into a `program_list`. The `program_list` object is a S4 class, which checks all the paths to the program executables first. 

If the decoy approach sould be used, first a decoy and NCBI GenBank database must be build. The following tutorial gives a overview over the standard approach. [Setup NCBI GenBank database](#setup-ncbi-genbank-database) explains, how to download all 2.5 million NCBI GenBank viral sequences and the connected amino acid sequences as well. Moreover, the generation of the decoy database is shown.

### Dependencies

In the first step a `program_list` object including all the path to the program exectuables must be generated. The following programs are needed for the virDisco.

**CAUTION** Some changes to the Pauda source code have to be done to use Pauda in our pipeline: [Changes to the Pauda code](doc/pauda_changes.md)

1. Bowtie2 DNA mapper http://bowtie-bio.sourceforge.net/bowtie2/index.shtml
2. Star mapper \[optional\] https://github.com/alexdobin/STAR
3. PAUDA - a poor man’s BLASTX https://ab.inf.uni-tuebingen.de/software/pauda
4. PANDAseq https://github.com/neufeld/pandaseq
5. ETE Toolkit http://etetoolkit.org/download/
6. BLAST+ executables https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download
7. Seqtk https://github.com/lh3/seqtk
8. Samtools http://www.htslib.org/
9. Trimmomatic http://www.usadellab.org/cms/?page=trimmomatic

The function `set_program_list` generates a S4 object of the paths to the executables and checks if all files are existing.

```R
program_list <- set_program_list(bowtie_dir = file.path(programDir, ... , "bowtie2"),
                                 star_dir = file.path(programDir, ... , "STAR"),
                                 pauda_dir = file.path(programDir, ... , "pauda-run"),
                                 bowtie_build_dir = file.path(programDir, ... , "bowtie2-build"),
                                 pauda_build_dir = file.path(programDir, ... , "pauda-build"),
                                 pandaseq_dir = file.path(programDir, ... , "pandaseq"),
                                 ete3_dir = file.path(programDir, ... , "ete3"),
                                 blastn_dir = file.path(programDir, ... , "blastn"),
                                 seqtk_dir = file.path(programDir, ... , "seqtk"),
                                 samtools_dir = file.path(programDir, ... , "samtools"),
                                 trimmomatic_dir = file.path(programDir, ... , "trimmomatic-0.36.jar"))
```

### S4 class 'par_list'

The viral detection pipeline is controlled by a S4 object of the class `par_list`. In this class all parameters for the detection pipeline are stored. Some of the representations have default values. 

```R
setClass(
  Class = "par_list",
  representation = representation(
    num_decoy_reads = "numeric",      ## number of generated decoy reads, if decoy is true [500]
    min_num_reads = "numeric",        ## mimimum number of reads per reference [50] 
    min_coverage = "numeric",         ## mimimum coverage of the reference by reads to keep the hit [0.05] 
    map_dna_in = "list",              ## internal file storage for dna mapping 
    map_dna_stats = "list",           ## internal list for DNA mapping statistics  
    map_pep_in = "list",              ## internal file storage for amino mapping  
    decoy = "logical",                ## should the decoy approach be run [false]
    tax = "logical",                  ## should the tax trees are generated [true]
    qc = "logical",                   ## should the quality control by trimmomatic be run [true]
    clean = "logical",                ## should intermediate files be deleted [true] 
    paired = "logical",               ## should paired read infiles assumed [false], but will be checked internally
    plot = "logical",                 ## should the final visualization of the mapped reads plotted [true]
    black_list = "character",         ## list of corrupt NCBI GenBAnk IDs [Null]
    gen_prot_sep = "character",       ## the seperator, how the genebank_id is seperated prom the prot_id [_]
    check_host = "logical",           ## should the host be checked by blastn [true]
    run_dna_mapping = "logical",      ## should the DNA mapping be run [true]
    run_pep_mapping = "logical",      ## should the amino acid mapping be run? [true]
    consensus = "logical",            ## should the consensus of the reads be generated [true]
    tmp_dir = "character",            ## path to the temp dir [/home/temp]
    sql_dir = "character",            ## path to the sql dir [/home/sql]
    index_genome_dir = "character",   ## path to the genome index generated by Star or Bowtie2
    index_amino_dir = "character",    ## path to the amino index generated by Pauda
    ref_seq_file = "character",       ## path to the reference.fasta
    prot_info = "tbl_dbi",            ## sqlite3 database of the protein information
    species_info = "tbl_dbi",         ## sqlite3 database of the species/strain information
    plot_id = "character",            ## should only a subset of genebank_ids be plotted?
    mapper = "character",             ## sould the Bowtie2 or Star mapper be used [bowtie]
    num_plot = "numeric",             ## how many plots of the TOP`num_plot` should be generated [25]
    ncore = "numeric",                ## how many cores should be used 
    pdf_file = "character"            ## name of the final plot pdf file
  ),
  prototype = prototype(
    num_decoy_reads = 500,
    min_coverage = 0.05,
    min_num_reads = 50,
    decoy = FALSE,
    tax = TRUE,
    clean = TRUE,
    paired = FALSE,
    plot = TRUE,
    plot_id = "",
    run_dna_mapping = TRUE,
    run_pep_mapping = TRUE,
    consensus = TRUE,
    gen_prot_sep = "_",
    black_list = "",
    check_host = TRUE,
    mapper = "bowtie",
    num_plot = 25,
    ncore = 1,
    prot_info = structure(tibble(), class = c("tbl_dbi", "empty")),
    species_info = structure(tibble(), class = c("tbl_dbi", "empty")),
    tmp_dir = file.path("/home/temp"),
    sql_dir = file.path("/home/sql")
  )
  [...] ## validity functions are truncated, see R/class.R for more information
)


```


### File setup

While the run of the virDisco many files are produced and needed. Therefore a good file system managment should be used and setup. It is not a good idea to store and save all the input and output files into one single folder. The package includes 10000 paired reads from a Illumina MiSeq. Some of the steps are redundant but will help to understand the process.

All the files will be stored in the `main_dir`, which is located in the tmp folder of your PC. Change this line to use a different folder as root folder. Further, we need a tmp folder, here `tmp_viral_dir`,  to store all the temporal files. In this example it does not really matter but in a real example the intermediate files become really big and must not be stored.

```R
## install packages
## install.packages("pacman")
p_load(plyr, ShortRead, Biostrings)

## setup demonstration file system
main_dir <- tempdir()
in_dir <- file.path(main_dir, "input")
out_dir <- file.path(main_dir, "output")
tmp_viral_dir <- file.path(main_dir, "tmp")
dir.create(in_dir)
dir.create(out_dir)
```

### Example read files and viral reference genomes

The example input files can be used directly, stored in the `/data` folder of this project or loaded directly in R by the following commands. Still, the external programs need the fastq files saved on disc. Therefore, we write the fastq reads to two fastq files. We assume always to find gzipped files. 

```R
## load the data
data(infected_fastq)
R1_fq <- file.path(in_dir, "NGS-10001_R1.fastq.gz")
R2_fq <- file.path(in_dir, "NGS-10001_R2.fastq.gz")

## write the read data to fastq files
mapply(writeFastq, infected_fastq, list(R1_fq, R2_fq))
```

### Build reference genome for Bowtie2 and Pauda

In the following we want to detect some viral strains in the infected fastq files. To make it more convenient, we have already build a small subset of DNA sequences inclduing viral strains, which might have been infected our sample. Therefore, we want now map the fastq reads to the reference DNA sequences. First have a closer look to the reference sequences.

```R
## load the reference DNA sequences
data(dna_seqs)
```

The reference sequences are all stored in the `DNAStringSet` container coming from the R package `Biostrings`. Here we have 287 sequences of the Morbillivirus, which might be infected our sample. Some of the reads should belong to some of the viral strains. 

```R
R> dna_seqs
   A DNAStringSet instance of length 287
       width seq                                             names
   [1]  1800 ACCAGACAAAGCTGGCTAGGGG...CTTCCACCGACACTGTCTCCAA AY949833 AY949833...
   [2]   430 CAAGGTATGTTTCACGCTTATC...CCTATACCCAGCTTTGTCTGGT AY949834 AY949834...
   [3]  9050 GTAGAATAACAGATAATGATAA...CATCTCAATCAACCAGATCCTA HQ829972 HQ829972...
   [4]  9050 GTAGAATAACAGATAATGATAA...CATCTCAATCAACCAGATCCTA HQ829973 HQ829973...
   [5]   369 GCTGTAATTAGAAATGCTCAGC...TAAAGAGAAAGAAATCAAAGAG KU053510 KU053510...
   ...   ... ...
 [283]  4865 CCATTAAAAAGGGCACAGACGT...ACTCGTTAGGTTATATATACAC EMU49404 U49404 E...
 [284]   389 GAAGAGGTTAAGGGAATCGCAG...GAATGGGGATAGTTGCTGGATC CDU76708 U76708 C...
 [285]   389 GAAGAGGTTAAGGGAATCGCAG...GAATGGGGATAGTTGCTGGATC CDU76709 U76709 C...
 [286]  2193 TGAATCTGAGCAACAATCGACA...TTAATTAATAAATAACTAAAGA X80757 X80757 C.m...
 [287]   924 GCATTAATTTTAGATATCAAAA...TCACACTTTCATCAGTATTACA X84739 X84739 Por...
```

Further, we have also the amino acid sequences of the DNA sequences. Overall 521 amino acid sequences, each coding for a gene of a viral strain, are avialable.

```R
data(aa_seqs)
```

The amino acid sequences are stored in a `AAStringSet` container giving the same usability as for the DNA sequences.

```R
R> aa_seqs
   A AAStringSet instance of length 521
       width seq                                             names
   [1]   523 MATLLRSLALFKRNKDRTPIIA...LLENQSSHDTTAHVYNDKDLLG AAX47056.2_AY9498...
   [2]   106 QGMFHAYPVLVDSRQRELVSRI...RLETSEIKEWFKLIGYGALIRE AAX47057.1_AY9498...
   [3]   523 MATLLRSLALFKRNKDRTPLTA...LLENQGPRDVTAHVYNDKDLLG AEO51046.1_HQ8299...
   [4]   506 MAEEQAYHVNKGLECLKSLREN...LNDVKSGKDLGEFYQMVKKIIK AEO51047.1_HQ8299...
   [5]   335 MTEVYDFDRSAWDVKGSIAPIE...PQEFRVYDDVIINDDQGLFKIL AEO51048.1_HQ8299...
   ...   ... ...
 [517]   130 EEVKGIADADSLVVPASAVSNR...GTIKKGTGERLASHGMGIVAGS AAB19205.1_CDU767...
 [518]   552 MASNDNSVIYHSFLTVILLVVV...PKSTPGLKPDLTGTTKSYVRSL CAA56731.1_X80757...
 [519]   289 ALILDIKRTPGNKPRIAEMICD...LLENQSSHDTTAHVYNDKDLLG CAA59229.1_X84739...
 [520]   288 FLDGIDKAQEDHEKYHSNWRAM...IIRDYGKQMAGDGCVASGQDED BAX84739.1_LC1608...
 [521]   470 MNPNQKIITIGSVSLGLVVLNI...DHEVADWSWHDGAILPFDIDKM AFX84739.1_CY1268...
```

The user is free to build up his own DNA and amino acid sequence database. We used the information on the NCBI GenBank FTP server ftp://ftp.ncbi.nlm.nih.gov/genbank. All available viral strains from the NCBI ftp server can be downloaded and parsed. The NCBI GenBank files are stored in the `embl` format and any given information can be gathered by the EMBOSS Programs https://www.ebi.ac.uk/Tools/emboss/. 

```R
viral_ref_dna_fa <- file.path(in_dir, "viral_ref_dna.fa") 
viral_ref_aa_fa <- file.path(in_dir, "viral_ref_aa.fa") 

## write the DNA sequences as fasta file
writeXStringSet(dna_seqs, viral_ref_dna_fa)
writeXStringSet(aa_seqs, viral_ref_aa_fa)

## set the mapper index dir
viral_index_dir <- file.path(main_dir, "viral_index")

## run the index 
viral_index_list <- build_index(dna_set = dna_seqs,
                                aa_set = aa_seqs,
                                index_dir = viral_index_dir,
                                index_name = "viral",
                                force = FALSE) ## should the given dir be overwriten?
```

### Setup SQL database

One main feature of the virDisco is the visualization of the mapping results. Only a subset of the findings will be overall plotted, given by the parameter `pat_list["num_plot"]`. In this example we have already to sqlite3 databases. One inlducing all the protein and genebank_ids as well as the gene/protein start position and end position. This database can be very big. In our example only 519 genes are included. There is no more time needed  to filter the data if there would be millions of rows. 

```R
## load the data implemented in the package
data(aa_info_db)
```

The `aa_info_db` includes five columns shown in the following. Each gene (`prot_id`) has at least one species `genebank_id`.

```R
R> aa_info_db
 # A tibble: 519 x 5
       prot_id genebank_id pos_start pos_end    ind
         <chr>       <chr>     <dbl>   <dbl>  <int>
  1 AHZ20683.1    KJ482570         1     312 157109
  2 ARQ82876.1    KX914861         1     170 221056
  3 ARQ82877.1    KX914862         1     170 221057
  4 ARQ82878.1    KX914863         1     170 221058
  5 ARQ82879.1    KX914864         1     170 221059
  6 ASV51313.1    KX943319         1    1824 235357
  7 ASV51314.1    KX943320         1    1824 235358
  8 ASV51315.1    KX943321         1    1824 235359
  9 ASV51316.1    KX943322         1    1824 235360
 10 ASV51317.1    KX943323         1    1824 235361
 # ... with 509 more rows
```

The second database `strain_info_db` includes the infromation on the species, the length of the sequence, tax id, and more information on the organism and the description.

```R
data(strain_info_db)
```

```R
R> select(strain_info_db,
 +        genebank_id, -Accession, tax_id:Description)
 # A tibble: 287 x 6
    genebank_id tax_id Accession Length               Organism
          <chr>  <chr>     <chr>  <int>                  <chr>
  1    FJ648457  38270  FJ648457   1946 Porpoise morbillivirus
  2    FJ842380  36410  FJ842380    158 Cetacean morbillivirus
  3    FJ842381  36410  FJ842381    358 Cetacean morbillivirus
  4    FJ842382  36410  FJ842382    904 Cetacean morbillivirus
  5    GQ149614  36410  GQ149614    145 Cetacean morbillivirus
  6    HQ829972  36410  HQ829972   9050 Cetacean morbillivirus
  7    HQ829973  36410  HQ829973   9050 Cetacean morbillivirus
  8    JN210891  36410  JN210891    389 Cetacean morbillivirus
  9    JQ326990  36410  JQ326990    551 Cetacean morbillivirus
 10    JQ326991  36410  JQ326991    541 Cetacean morbillivirus
 # ... with 277 more rows, and 1 more variables: Description <chr>
```

To make it easier for the user, we implemented two R functions to generate the sqlite3 databases. Both functions need the given information and will then setup the sqlite3 databases in the given `sql_dir`. Please make sure, that the file system can handle sqlite3 databases.

```R
aa_info_db_file <- file.path(in_dir, "aa_info_db.sqlite3")

setup_aa_info_sample_sqlite(prot_id = aa_info_db$prot_id,
                            genebank_id = aa_info_db$genebank_id,
                            prot_start = aa_info_db$pos_start,
                            prot_end = aa_info_db$pos_end,
                            db_file = aa_info_db_file)

strain_info_db_file <- file.path(in_dir, "strain_info_db.sqlite3")

setup_species_info_sqlite(genebank_id = strain_info_db$genebank_id,
                          length = strain_info_db$Length,
                          description = strain_info_db$Description,
                          tax_id = strain_info_db$tax_id,
                          db_file = strain_info_db_file)

```

Now all the setup is done for the final mapping run.

### Start artifical genome mapping

The mapping of the sequence reads is controlled by the fuction `artificial_genome_mapping`. The function needs only three inputs, the infiles, the outfile, and the S4 class `par_list`. The later is needed to get all the parameters trough the function calls. Here we also did some modifications. `par_viral_list["tmp_dir"]` changes the default temp dir and `par_viral_list["check_host"] <- FALSE` avoids host checking by blastn. The host checking can be very time consuming.

Finally, the file setup is done by the function `get_sub_files`. Therefore, the name of the sample is needed and the indir, where the sample file is stored, and the out dir, where the results files should be written to. Finally, the artificial mapping of the sequence reads is started.

```R

## parameter list
par_viral_list <- set_par_list(index_genome_dir = viral_index_list$bowtie_index, 
                               index_amino_dir = viral_index_list$pauda_index,
                               ref_seq_file = viral_ref_dna_fa, 
                               prot_info_df = tbl(src_sqlite(aa_info_db_file), "aa_info_df"),
                               species_info_df = tbl(src_sqlite(strain_info_db_file), "species_info_df"))

par_viral_list["tmp_dir"] <- tmp_viral_dir
par_viral_list["check_host"] <- FALSE


viral_files <- get_sub_files("NGS-10001",
                             in_dir = file.path(in_dir),
                             out_dir = file.path(in_dir))


## run the partial mapping
artificial_genome_mapping(in_file = viral_files$in_file,
                          out_file = viral_files$out,
                          par_list = par_viral_list)
```

In the following the log of the artificial genome mapping is printed. The function itself does not return any value.

```R
R> artificial_genome_mapping(in_file = viral_files$in_file,
 +                           out_file = viral_files$out,
 +                           par_list = par_viral_list)
 Dez 04 14:01:33 ..... Write to /tmp/RtmpmN8czE/input/NGS-10001
 Dez 04 14:01:33 ..... Temp dir /tmp/RtmpmN8czE/tmp not found. Will be created...
 Dez 04 14:01:34 ..... Gene and species information is correct
 Dez 04 14:01:34 ..... Start trimming
 Dez 04 14:01:35 ..... Start DNA mapping
 Dez 04 14:01:36 ..... Working on NGS_10001_dna.sam
 Dez 04 14:01:37 ..... Save DNA mapping results...
 Dez 04 14:01:37 ..... Start AMINO mapping
 Dez 04 14:01:37 ..... Run pandaseq to build up one fastq file
 Dez 04 14:01:37 ..... Run pauda
 Dez 04 14:01:38 ..... Process pauda hits
 Dez 04 14:01:40 ..... Save AMINO mapping results...
 Dez 04 14:01:40 ..... Save hits to xlsx
 Dez 04 14:01:40 ..... Generate pylogenetic tree
 Dez 04 14:01:41 ..... Generate consensus of reads to reference
 Dez 04 14:01:44 ..... Get the number of raw reads
 Dez 04 14:01:44 ..... Build sample info
 Dez 04 14:01:44 ..... Start generating the mapping pdf
   |======================================================================| 100%
 Dez 04 14:01:57 ..... Transfrom png files to one pdf
 Dez 04 14:02:22 ..... Finished
```

## Output files

The output files containing three important files

1. The ordered counts of the mapped DNA and amino acid reads
2. The visualization of the mapping results into a single pdf file
3. The phylogenetic tree of all findings, where a tax ID was available

### Count \*.xlsx file

The count file includes all the counts of the mapped DNA reads and the translated amino acid reads. Then the results are ranked by the combined ranks of the DNA and amino acid ranks. The last column indicates the description of the viral strain, while the first column reports the NCBI GenBank ID, which can be directly inserted on the NCBI homepage to get more infomation on the finding.

<p align="center">
  <img src="img/NGS-10001_xlsx.png" width="800">
</p>

### Summary file of the sequence visualization

The plotting function gnerates first a overview plot of the standard informations on the sample name, the number of reads and the number of reads after quality control, if the reads were paired, and the running time. Finally, a host check will be reported based on 100 randomly selected reads, which have been blasted.

<p align="center">
  <img src="img/NGS-10001_00.png" width="700">
</p>

### First and second figure out of 25

Depending on the parameter in `par_list["num_plot"]` 25 plots are generated from the TOP25. In general the position of each single maped read from the DNA mapping and the amino mapping is visualized.

<p align="center">
  <img src="img/NGS-10001_01.png" width="700">
</p>

<p align="center">
  <img src="img/NGS-10001_02.png" width="700">
</p>

### Phylogenetic tree by the findings

We use the ete-toolkit for the automatic generation of phylogenetic trees. This is more a overview of findings.

<p align="center">
  <img src="img/NGS-10001_tree.png" width="500">
</p>

# Setup NCBI GenBank database

If the user has not a sequence database available, it might be feasible to download the NCBI GenBank database. in addition, the generation of the decoy database is explained.

[Download, Processing and Saving of the NCBI GenBank viral database](doc/setup_ncbi_databse.md)


