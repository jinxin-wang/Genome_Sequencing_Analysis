# A rule to extract exom variant from a whole genome mutect2
rule extract_exom_mutect2:
    input:
        Mutect2_vcf = "Mutect2_TvN/{tsample}_Vs_{nsample}_twicefiltered_TvN.vcf.gz",
        Mutect2_vcf_index = "Mutect2_TvN/{tsample}_Vs_{nsample}_twicefiltered_TvN.vcf.gz.tbi",
        exom_bed = config["EXOM_BED"]
    output:
        exom_Mutect2 = temp("Mutect2_TvN_exom/{tsample}_Vs_{nsample}_twicefiltered_TvN_exom_unsorted.vcf.gz")
    log:
        "logs/Mutect2_TvN_exom/{tsample}_Vs_{nsample}_TvN.vcf.txt"
    params:
        queue = "mediumq",
        bcftools = config["APP_BCFTOOLS"]        
    threads : 1
    resources:
        mem_mb = 5000
    shell:
        '{params.bcftools} view -l 9 -R {input.exom_bed} -o {output.exom_Mutect2} {input.Mutect2_vcf} 2> {log}'

# A rule to sort exom vcf
rule sort_exom_mutect2:
    input:
        Mutect2_vcf = "Mutect2_TvN_exom/{tsample}_Vs_{nsample}_twicefiltered_TvN_exom_unsorted.vcf.gz",
    output:
        exom_Mutect2 = "Mutect2_TvN_exom/{tsample}_Vs_{nsample}_twicefiltered_TvN_exom.vcf.gz"
    log:
        "logs/Mutect2_TvN_exom/{tsample}_Vs_{nsample}_TvN_sort.txt"
    params:
        queue = "shortq",
        vcfSort = config["APP_VCFSORT"]
    threads : 1
    resources:
        mem_mb = 5000
    shell:
        'bgzip -d {input.Mutect2_vcf} && '
        '{params.vcfSort} Mutect2_TvN_exom/{wildcards.tsample}_Vs_{wildcards.nsample}_twicefiltered_TvN_exom_unsorted.vcf > Mutect2_TvN_exom/{wildcards.tsample}_Vs_{wildcards.nsample}_twicefiltered_TvN_exom.vcf && '
        'bgzip Mutect2_TvN_exom/{wildcards.tsample}_Vs_{wildcards.nsample}_twicefiltered_TvN_exom.vcf'

# A rule to extract exom variant from a whole genome mutect2
rule index_exom_mutect2:
    input:
        exom_Mutect2 = "Mutect2_TvN_exom/{tsample}_Vs_{nsample}_twicefiltered_TvN_exom.vcf.gz"
    output:
        exom_Mutect2_index = "Mutect2_TvN_exom/{tsample}_Vs_{nsample}_twicefiltered_TvN_exom.vcf.gz.tbi"
    log:
        "logs/Mutect2_TvN_exom/{tsample}_Vs_{nsample}_TvN_index.txt"
    params:
        queue = "shortq",
        gatk = config["APP_GATK"]        
    threads : 1
    resources:
        mem_mb = 10240
    conda: "pipeline_GATK_2.1.4_V2"
    shell:
        'gatk IndexFeatureFile -F {input.exom_Mutect2} 2> {log}'

# A rule to generate a bed from mutect2 vcf  
rule get_variant_bed_exom:
    input:
        Mutect2_vcf = "Mutect2_TvN_exom/{tsample}_Vs_{nsample}_twicefiltered_TvN_exom.vcf.gz",
        Mutect2_vcf_index = "Mutect2_TvN_exom/{tsample}_Vs_{nsample}_twicefiltered_TvN_exom.vcf.gz.tbi"
    output:
        BED = "variant_bed_TvN_exom/{tsample}_Vs_{nsample}_TvN_exom.bed"
    log:
        "logs/variant_bed_TvN_exom/{tsample}_Vs_{nsample}_TvN_exom.bed.txt"
    params:
        queue = "mediumq",
        vcf2bed = config["APP_VCF2BED"]        
    threads : 1
    resources:
        mem_mb = 5000
    shell:
        'zcat {input.Mutect2_vcf} | python2 {params.vcf2bed} - > {output.BED} 2> {log}'

## Run samtools mpileup 
rule samtools_mpileup_exom:
    input:
        BED = "variant_bed_TvN_exom/{tsample}_Vs_{nsample}_TvN_exom.bed",
        GENOME_REF_FASTA = config["GENOME_FASTA"],
        BAM = "bam/{tsample}.nodup.recal.bam" if config["REMOVE_DUPLICATES"]=="True" else "bam/{tsample}.recal.bam",
        BAI = "bam/{tsample}.nodup.recal.bam.bai" if config["REMOVE_DUPLICATES"]=="True" else "bam/{tsample}.recal.bam.bai"
    output:
        PILEUP = "pileup_TvN_exom/{tsample}_Vs_{nsample}_TvN_exom.pileup.gz"
    log:
        "logs/pileup_TvN_exom/{tsample}_Vs_{nsample}_TvN_exom.pileup.txt"
    params:
        queue = "mediumq",
        samtools = config["APP_SAMTOOLS"]
    threads : 1
    resources:
        mem_mb = 5000
    shell:
        '{params.samtools} mpileup -a -B -l {input.BED} -f {input.GENOME_REF_FASTA} {input.BAM} | gzip - > {output.PILEUP} 2> {log}'

# A rule to annotate mutect2 tumor versus normal results with oncotator  
rule oncotator_exom:
    input:
        ONCOTATOR_DB = config["ONCOTATOR_DB"],
        Mutect2_vcf = "Mutect2_TvN_exom/{tsample}_Vs_{nsample}_twicefiltered_TvN_exom.vcf.gz",
        Mutect2_vcf_index = "Mutect2_TvN_exom/{tsample}_Vs_{nsample}_twicefiltered_TvN_exom.vcf.gz.tbi"
    output:
        MAF="oncotator_TvN_exom/{tsample}_Vs_{nsample}_annotated_TvN_exom.TCGAMAF"
    params:
        queue = "mediumq",
        #activate_oncotator = config["ONCOTATOR_ENV"],
        oncotator = config["APP_ONCOTATOR"]
    log:
        "logs/oncotator_TvN_exom/{tsample}_Vs_{nsample}_annotated_TvN_exom.TCGAMAF"
    threads : 1
    resources:
        mem_mb = 100000
    shell:
        '{params.oncotator} --input_format=VCF --output_format=TCGAMAF --tx-mode EFFECT --db-dir={input.ONCOTATOR_DB} {input.Mutect2_vcf} {output.MAF} hg19 2> {log}'
        #'set +u; source {params.activate_oncotator}; set -u; oncotator --input_format=VCF --output_format=TCGAMAF --tx-mode EFFECT --db-dir={input.ONCOTATOR_DB} {input.Mutect2_vcf} {output.MAF} hg19; deactivate;'

## A rule to simplify oncotator output on tumor vs normal samples
rule oncotator_reformat_TvN_exom:
    input:
        maf="oncotator_TvN_exom/{tsample}_Vs_{nsample}_annotated_TvN_exom.TCGAMAF"
    output:
        maf ="oncotator_TvN_maf_exom/{tsample}_Vs_{nsample}_TvN_selection_exom.TCGAMAF",
        tsv ="oncotator_TvN_tsv_exom/{tsample}_Vs_{nsample}_TvN_exom.tsv"
    log:
        "logs/oncotator_exom/{tsample}_Vs_{nsample}_TvN_selection_exom.txt"
    params:
        queue = "shortq",
        oncotator_extract_TvN = config["APP_ONCOTATOR_EXTRACT_TUMOR_VS_NORMAL"]
    threads : 1
    resources:
        mem_mb = 10000
    shell:
        'python2.7 {params.oncotator_extract_TvN} {input.maf} {output.maf} {output.tsv} 2> {log}'

## A rule to cross oncotator output on tumor vs normal samples with pileup information
rule oncotator_with_pileup_TvN_exom:
    input:
        tsv = "oncotator_TvN_tsv_exom/{tsample}_Vs_{nsample}_TvN_exom.tsv",
        pileup = "pileup_TvN_exom/{tsample}_Vs_{nsample}_TvN_exom.pileup.gz"
    output:
        tsv = "oncotator_TvN_tsv_pileup_exom/{tsample}_Vs_{nsample}_TvN_with_pileup_exom.tsv"
    log:
        "logs/oncotator_exom/{tsample}_Vs_{nsample}_TvN_with_pileup_exom.txt"
    params:
        queue = "shortq",
        oncotator_cross_pileup = config["APP_ONCOTATOR_X_PILEUP"]
    threads : 1
    resources:
        mem_mb = 500
    shell:
        'python {params.oncotator_cross_pileup} {input.pileup} {input.tsv} {output.tsv}'

## A rule to cross oncotator output on tumor vs normal samples with COSMIC information
rule oncotator_with_COSMIC_TvN_exom:
    input:
        tsv = "oncotator_TvN_tsv_pileup_exom/{tsample}_Vs_{nsample}_TvN_with_pileup_exom.tsv"
    output:
        tsv = "oncotator_TvN_tsv_COSMIC_exom/{tsample}_Vs_{nsample}_TvN_with_COSMIC_exom.tsv"
    log:
        "logs/oncotator_exom/{tsample}_Vs_{nsample}_TvN_with_COSMIC_exom.txt"
    params:
        queue = "shortq",
        oncotator_cross_cosmic = config["APP_ONCOTATOR_X_COSMIC_T_N"],
        cosmic_mutation = config["COSMIC_MUTATION"],
        cancer_census_oncogene = config["CANCER_CENSUS_ONCOGENE"],
        cancer_census_tumorsupressor = config["CANCER_CENSUS_TUMORSUPRESSOR"]
    threads : 1
    resources:
        mem_mb = 10000
    shell:
        'python2.7 {params.oncotator_cross_cosmic}  {input.tsv} {output.tsv} {params.cosmic_mutation} {params.cancer_census_oncogene} {params.cancer_census_tumorsupressor} 2> {log}'

