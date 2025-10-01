# vcftools2snpEff-pipeline

Run **vcftools** on multiple genomic regions in parallel, update SNP IDs, annotate with **snpEff**, and generate filtered CSV outputs.

---

## 📦 Requirements

- Linux / HPC environment  
- [vcftools](https://vcftools.github.io/) (loadable via `ml load vcftools`)  
- [snpEff](https://pcingola.github.io/SnpEff/) (loadable via `ml load snpEff`)  
- GNU Parallel (default in Linux, installable via `sudo apt install parallel` or `yum install parallel`)
- Java 8+ (required for snpEff) 

---

## 📂 Repository Structure
```
vcftools-snpEff-pipeline/
│── vcftools-snpEff_parallel.sh # Main pipeline script
│── example_regions.csv # Example input CSV
│── README.md # Documentation

```
## 📝 CSV Format

### ⚠️ The first line (header) will be skipped automatically.

### ⚠️ CSV must be comma-separated.

The input CSV must contain the following columns:
```
chr,from_bp,to_bp,out
1,15346352,15347941,Os01g0372500
1,22215593,22241305,Os01g0576100
2,4280502,4285929,Os02g0177600
3,8406809,8408296,Os03g0259400
```

- `chr` → Chromosome  
- `from_bp` → Start position (bp)  
- `to_bp` → End position (bp)  
- `out` → Output prefix  
---

## 🚀 Usage

```bash
chmod +x vcftools-snpEff_parallel.sh

# Run with default NPROC=4 and snpEff DB=Oryza_sativa
./vcftools-snpEff_parallel.sh regions.csv /path/to/input.vcf.gz

# Run with custom snpEff DB and parallel jobs
./vcftools-snpEff_parallel.sh regions.csv /path/to/input.vcf.gz Oryza_sativa 8
```
- `$1` → input CSV file
- `$2` → input VCF file (.vcf.gz)
- `$3` → snpEff database (default: Oryza_sativa)
- `$4` → number of parallel jobs (default: 4)

## 📌 Outputs per region

For each row in CSV:

| File | Description |
|------|------------|
| `${out}.recode.vcf` | vcftools output for the region |
| `${out}.snpID.vcf` | SNP IDs updated (Chr<chrom>_<pos>) |
| `${out}.snpEff.vcf` | Annotated VCF via snpEff |
| `${out}.snpEff.csv` | Extracted columns for easy analysis |
| `${out}_HIGH_MODERATE.csv` | Filtered high/moderate impact variants |
| `${out}.table` | Variant table from GATK VariantsToTable | 

> **Note:** Intermediate `.recode.vcf` is automatically removed after processing.

# Step 0: Build snpEff Database

Before running the pipeline, you need a **snpEff database** for your species (e.g., `Oryza_sativa`).

---

## 1️⃣ Prepare Reference Files

You need the following files:

- Reference genome (FASTA)
- Gene annotation (GFF3 or GTF)

Example:

```
Oryza_sativa.fa # Reference genome
Oryza_sativa.gff3 # Gene annotation
```
## 2️⃣ Create Database Folder

Assuming `~/snpEff/data/` as the snpEff database path:
```bash
mkdir -p ~/snpEff/data/Oryza_sativa
cp Oryza_sativa.fa ~/snpEff/data/Oryza_sativa/sequences.fa
cp Oryza_sativa.gff3 ~/snpEff/data/Oryza_sativa/genes.gff
```
## 3️⃣ Edit snpEff Config

Open snpEff.config (e.g., /opt/apps/snpEff/snpEff.config) and add:

```bash
Oryza_sativa.genome : Oryza_sativa
```
Make sure the path to sequences is correct (~/snpEff/data/Oryza_sativa/sequences.fa).

## 4️⃣ Build the Database
```bash
java -Xmx4G -jar /opt/apps/snpEff/snpEff.jar build -gff3 -v Oryza_sativa
```
- `gff3` → use GFF3 annotation
- `v` → verbose mode
The database will be created for `Oryza_sativa`

### 5️⃣ Test the Database
```bash
java -jar /opt/apps/snpEff/snpEff.jar eff Oryza_sativa example.vcf | head
```
If you see SNP/MNP annotations, the database is ready to use.