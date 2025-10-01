#!/bin/bash
# run_vcftools_parallel.sh
# Description: Run vcftools on multiple regions in parallel using CSV input
# Usage: ./vcftools-snpEff_parallel.sh regions.csv /path/to/input.vcf.gz SNPEFF_DB NPROC

set -euo pipefail

ml load vcftools
ml load gatk
#ml load snpeff

CSV_FILE="$1"
VCF_FILE="$2"
SNPEFF_DB="${3:-Oryza_sativa}"
NPROC="${4:-4}"  # number concurrent jobs (default = 4)

# Check input files
if [[ ! -f "$CSV_FILE" ]]; then
    echo "❌ Error: CSV file not found!"
    exit 1
fi

if [[ ! -f "$VCF_FILE" ]]; then
    echo "❌ Error: VCF file not found!"
    exit 1
fi

echo "👉 Running pipeline in parallel with $NPROC jobs..."
echo "📂 Input VCF: $VCF_FILE"
echo "📑 Regions CSV: $CSV_FILE"
echo "🧬 snpEff DB: $SNPEFF_DB"

process_region() {
    chr="$1"
    from_bp="$2"
    to_bp="$3"
    out="$4"

    echo "🔹 Processing $out ..."
    SNPEFF_CMD="java -jar /opt/apps/snpEff/snpEff.jar ann $SNPEFF_DB"
    vcftools --gzvcf "$VCF_FILE" --chr "$chr" --from-bp "$from_bp" --to-bp "$to_bp" --out "$out" --recode
    awk 'BEGIN{OFS="\t"} /^#/ {print; next} { $3 = "Chr"$1"_"$2; print }' "${out}.recode.vcf" > "${out}.snpID.vcf"
    $SNPEFF_CMD "${out}.snpID.vcf" > "${out}.snpEff.vcf"
    grep -v "##" "${out}.snpEff.vcf" | cut -f 1-5,8 | tr '|' '\t' | cut -f 1-5,7-10 > "${out}.snpEff.csv"
    grep -v -E "MODIFIER|LOW" "${out}.snpEff.csv" > "${out}_HIGH_MODERATE.csv"
    gatk VariantsToTable -V "${out}.snpID.vcf" -SMA -F CHROM -F POS -F REF -F ALT -F ID -GF GT -O ./${out}.table
    cat ./${out}.table| head -n 1 |sed 's/.GT//g' > tmp
    cat ./${out}.table|sed '1d'| sed 's/|/\//g' >> tmp ; mv tmp ./${out}.table
    rm -f "${out}.recode.vcf"
    echo "✅ Done $out"
}

export -f process_region
export VCF_FILE SNPEFF_DB

tail -n +2 "$CSV_FILE" | parallel -j "$NPROC" --colsep ',' bash -lc '
    process_region {1} {2} {3} {4}
'

echo "✅ All parallel jobs completed!"
