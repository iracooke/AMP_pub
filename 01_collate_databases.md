
# Obtaining the positive dataset for ampir

March 2020

Four recently updated antimicrobial peptide (AMP) databases were used:

  - [APD 3](http://aps.unmc.edu/AP/) by [Wang et
    al. 2016](https://academic.oup.com/nar/article/44/D1/D1087/2503090)
  - [DRAMP 2.0](http://dramp.cpu-bioinfor.org/) by [Kang et
    al. 2019](https://www.ncbi.nlm.nih.gov/pubmed/31409791)
      - [DRAMP GitHub](https://github.com/CPUDRAMP/DRAMP2.0)
  - [dbAMP](http://140.138.77.240/~dbamp/index.php) by [Jhong et
    al. 2018](https://www.ncbi.nlm.nih.gov/pubmed/30380085)
  - [SwissProt](https://www.uniprot.org/uniprot/?query=keyword:%22Antimicrobial%20%5BKW-0929%5D%22%20OR%20%22antimicrobial%20peptide%22&fil=reviewed%3Ayes&sort=score)
    using the search term “antimicrobial peptide” and the keyword
    “Antimicrobial”.

## APD

The [Antimicrobial Peptide Database](http://aps.unmc.edu/AP/main.php)
was last updated March 16 2020 and contains 3,177 AMPs. An outdated
(2017) AMP sequence list is downloadable from
<http://aps.unmc.edu/AP/downloads.php> which currently contains 2,338
sequences. To include the updated AMP list,
<http://aps.unmc.edu/AP/database/mysql.php> was used to obtain the 3,177
AMPs. Synthetic AMPs were filtered out and 3,106 AMPs
remained.

``` r
APD <- readxl::read_xlsx("raw_data/APD_032020.xlsx", col_names = c("seq_name", "description", "seq_aa")) %>%
  filter(!grepl("Synthetic|synthetic", description)) %>%
  select(seq_name, seq_aa)
```

## DRAMP

From [DRAMP’s download page](http://dramp.cpu-bioinfor.org/downloads/),
the general AMP dataset was downloaded (which contain natural and
synthetic AMPs). The synthetic AMPs have to be removed from this dataset
as the focus is on predicting naturally occuring
AMPs.

``` r
dramp_general <- readxl::read_xlsx("raw_data/DRAMP_general_amps.xlsx") %>%
   filter(Protein_existence != "Synthetic",
         !grepl('Synthetic|synthetic', Source))
```

Filtering out the synthetic cases results in 4,314 proteins. From the
[General dataset download page on
figshare](https://figshare.com/s/f143f977cf8cf5fd5cf6), the DRAMP
general dataset was posted on 06/08/2019. However, according to the
“news and events” section, the [natural
dataset](http://dramp.cpu-bioinfor.org/browse/NaturalData.php) has been
updated several times since then. Because the natural dataset contains
the AMPs we are interested in, and is also more regularly updated (it
currently contains 4,394 sequences), the natural AMP data was obtained
using a scrape script.

``` bash
for i in $(seq -s ' ' 1 220);do

curl "http://dramp.cpu-bioinfor.org/browse/NaturalData.php?&end=5&begin=1&pageNow=${i}" -o p${i}.html
amp_ids=$(cat p${i}.html | grep -oE '(DRAMP[0-9]+)' | sort -u | tr '\n' ' ' | sed 's/ /%20/g')
curl "http://dramp.cpu-bioinfor.org/down_load/download.php?load_id=${amp_ids}&format=fasta" -o p${i}.fasta

done
```

This scrape script results in a html file for each webpage plus a FASTA
file containing the sequences in FASTA format for each page. The FASTA
files were concatenated into a single FASTA file and tidied up to remove
blank lines in the files.

``` bash
cat *.fasta >> dramp_nat.fasta
sed '/^$/d' dramp_nat.fasta > dramp_nat_tidy.fasta
```

The predicted AMPs were then filtered out to only leave experimentally
verified AMPs.

``` r
DRAMP <- read_faa("raw_data/dramp_nat_tidy.fasta") %>%
  filter(!grepl("Predicted", seq_name))
```

## dbAMP

The latest release of dbAMP is from 06/2019 and was downloaded from
their [download page](http://140.138.77.240/~dbamp/download.php). It
contains 4,270 experimentally verified natural and synthetic AMPs.
Synthetic AMPs were filtered out and 4,213 AMPs
remained.

``` bash
wget http://140.138.77.240/~dbamp/download/dbAMPv1.4.tar.gz -O raw_data/dbAMPv1.4.tar.gz

tar -xf raw_data/dbAMPv1.4.tar.gz -C raw_data
```

``` r
dbAMP <- readxl::read_xlsx("raw_data/dbAMPv1.4.xlsx") %>%
  filter(!grepl('Synthetic|synthetic', dbAMP_Taxonomy)) %>%
  select(dbAMP_ID, Sequence) %>%
  rename("seq_name" = "dbAMP_ID", "seq_aa" = "Sequence")
```

## SwissProt

AMPs were collected from UniProt using the following search terms:
“keyword:”Antimicrobial \[KW-0929\]" OR “antimicrobial peptide” AND
reviewed:yes" (3,546 sequences) Sequences longer than 300 amino acids
long were removed (3,264 sequences
left)

``` r
swissprot <- read_tsv("raw_data/uniprot-keyword__Antimicrobial+[KW-0929]_+OR+_antimicrobial+peptide%--.tab") %>%
  filter(Length <= 300) %>%
  select(Entry, Sequence) %>%
  rename("seq_name" = "Entry", "seq_aa" = "Sequence")
```

## Combine the databases

Combine AMP databases and remove duplicate sequences plus sequences that
contain nonstandard amino acids (8,324 sequences left)

``` r
combined_dbs <- rbind(APD, dbAMP, DRAMP, swissprot) %>%
  distinct(seq_aa, .keep_all = TRUE) %>%
  as.data.frame() %>%
  remove_nonstandard_aa()
```

Write file to FASTA

``` r
df_to_faa(combined_dbs, "cache/positive032020.fasta")
```

Use cd-hit to remove highly similar sequences (which leaves 5673
AMPs)

``` bash
cd-hit -i cache/positive032020.fasta -o cache/positive032020_98.fasta -c 0.98 -g 1
```