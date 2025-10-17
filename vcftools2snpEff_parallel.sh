#!/bin/bash
# run_vcftools_parallel.sh
# Description: Run vcftools on multiple regions in parallel using CSV input
# Usage: ./vcftools-snpEff_parallel.sh regions.csv /path/to/input.vcf.gz SNPEFF_DB

set -euo pipefail

ml load vcftools
ml load gatk

Pos=$1
VCF_FILE="$2"
SNPEFF_DB=${3:-Oryza_sativa}

SNPEFF_CMD="java -jar /opt/apps/snpEff/snpEff.jar ann $SNPEFF_DB"

while read line; do
	chr=$(echo ${line} | cut -d"," -f1)
	from_bp=$(echo ${line} | cut -d"," -f2)
	to_bp=$(echo ${line} | cut -d"," -f3)
	out=$(echo ${line} | cut -d"," -f4)
	
	echo "🔹 Processing $chr : $from_bp - $to_bp --> $out ..."
	vcftools --gzvcf "$VCF_FILE" --chr "$chr" --from-bp "$from_bp" --to-bp "$to_bp" --out "$out" --recode
	awk 'BEGIN{OFS="\t"} /^#/ {print; next} { $3 = "Chr"$1"_"$2; print }' "${out}.recode.vcf" > "${out}.snpID.vcf"
	$SNPEFF_CMD "${out}.snpID.vcf" > "${out}.snpEff.vcf"
	grep -v "##" "${out}.snpEff.vcf" | cut -f 1-5,8 | tr '|' '\t' | cut -f 1-5,7-10 > "${out}.snpEff.csv"
	grep -v -E "MODIFIER|LOW" "${out}.snpEff.csv" > "${out}_HIGH_MODERATE.csv"
	gatk VariantsToTable -V "${out}.snpID.vcf" -SMA -F CHROM -F POS -F REF -F ALT -F ID -GF GT -O ./${out}.table
	head -n 1 ${out}.table |sed 's/.GT//g' > ${out}.tmp.table
	sed '1d; s/|/\//g' ${out}.table >> ${out}.tmp.table
	mv ${out}.tmp.table ${out}.table
	rm -f "${out}.recode.vcf"
	echo "✅ Done $out"
done < $Pos
echo "✅ All jobs completed!"
