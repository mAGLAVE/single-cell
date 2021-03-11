"""
##########################################################################
These rules make the alignment of cell surface protein in single-cell RNA-seq.
##########################################################################
"""
wildcard_constraints:
    sample_name_adt_R=".+_ADT",
    sample_name_adt=".+_ADT"

"""
This rule makes the fastqc control-quality.
"""
rule fastqc_adt:
    input:
        fq = os.path.join(ALIGN_INPUT_DIR_ADT,"{sample_name_adt_R}{lane_R_complement}.fastq.gz")
    output:
        html_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt_R}/QC/fastqc/{sample_name_adt_R}{lane_R_complement}_fastqc.html"),
        zip_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt_R}/QC/fastqc/{sample_name_adt_R}{lane_R_complement}_fastqc.zip")
    threads:
        8
    conda:
        CONDA_ENV_QC_ALIGN_GE_ADT
    shell:
        "mkdir -p {ALIGN_OUTPUT_DIR_ADT}/{wildcards.sample_name_adt_R}/QC/fastqc && fastqc --quiet -o {ALIGN_OUTPUT_DIR_ADT}/{wildcards.sample_name_adt_R}/QC/fastqc -t {threads} {input}"

"""
This rule makes the multiqc from the fastqc and the fastq-screen results.
The function allows to get all QC input files for one specific sample (wildcards).
"""
def multiqc_inputs_adt(wildcards):
    name_R1_R2=[elem for elem in ALL_FILES_ADT if re.search(wildcards.sample_name_adt, elem)]
    name_R2=[elem for elem in name_R1_R2 if re.search("R2", elem)]
    files=[]
    for name in name_R1_R2:
        #fastqc
        files.append(os.path.join(ALIGN_OUTPUT_DIR_ADT,wildcards.sample_name_adt,"QC/fastqc",name) + "_fastqc.html")
        files.append(os.path.join(ALIGN_OUTPUT_DIR_ADT,wildcards.sample_name_adt,"QC/fastqc", name) + "_fastqc.zip")
    return files

rule multiqc_adt:
    input:
        #qc_files = lambda wildcards: glob.glob(os.path.join(OUTPUT_DIR_ADT, str(wildcards.sample_name_adt) + "/QC/*/" + str(wildcards.sample_name_adt) + "*")),
        qc_files2 = multiqc_inputs_adt
    output:
        html_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/QC/multiqc/{sample_name_adt}_RAW.html"),
        zip_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/QC/multiqc/{sample_name_adt}_RAW_data.zip")
    threads:
        1
    conda:
        CONDA_ENV_QC_ALIGN_GE_ADT
    shell:
        "mkdir -p {ALIGN_OUTPUT_DIR_ADT}/{wildcards.sample_name_adt}/QC/multiqc && multiqc -n {wildcards.sample_name_adt}'_RAW' -i {wildcards.sample_name_adt}' RAW FASTQ' -p -z -f -o {ALIGN_OUTPUT_DIR_ADT}/{wildcards.sample_name_adt}/QC/multiqc {input}"


"""
This rule makes the alignment by kallisto.
The function alignment_inputs_adt allows to get all fastq input files for one specific sample (wildcards).
"""
def alignment_inputs_adt(wildcards):
    files=[]
    files=[elem for elem in PATH_ALL_FILES_ADT_FQ_GZ if re.search(wildcards.sample_name_adt, elem)]
    return sorted(files)

rule alignment_adt:
    input:
        fq_link = alignment_inputs_adt,
        html_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/QC/multiqc/{sample_name_adt}_RAW.html")
    output:
        output_bus_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/output.bus"),
        transcripts_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/transcripts.txt"),
        matrix_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/matrix.ec"),
        run_info_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/run_info.json")
    params:
        kbusdir = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS")
    conda:
        CONDA_ENV_QC_ALIGN_GE_ADT
    shell:
        "mkdir -p {params.kbusdir} && kallisto bus -i {KINDEX_ADT} -o {params.kbusdir} -x {SCTECH} -t {threads} {input.fq_link}"

"""
This rule sort the results of alignment, by bustools.
"""
rule sort_file_adt:
    input:
        output_bus_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/output.bus")
    output:
        sorted_bus_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/{sample_name_adt}_sorted.bus")
    params:
        tmp_dir=os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/tmp")
    threads:
        8
    conda:
        CONDA_ENV_QC_ALIGN_GE_ADT
    shell:
        "mkdir -p {params.tmp_dir} && bustools sort -T {params.tmp_dir}/tmp -t {threads} -m 12G -o {output} {input} && rm -r {input} {params.tmp_dir}"

"""
This rule correct UMI from the sorted results of alignment, by bustools.
"""
rule correct_UMIs_adt:
    input:
        sorted_bus_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/{sample_name_adt}_sorted.bus")
    output:
        corrected_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/{sample_name_adt}_corrected.bus")
    threads:
        1
    conda:
        CONDA_ENV_QC_ALIGN_GE_ADT
    shell:
        "bustools correct -w {WHITELISTNAME} -o {output} {input} && rm {input}"

"""
This rule count UMI from the corrected sorted results of alignment, by bustools.
"""
rule build_count_matrix_adt:
    input:
        corrected_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/{sample_name_adt}_corrected.bus"),
        transcripts_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/transcripts.txt"),
        matrix_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/matrix.ec")
    output:
        mtx_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/{sample_name_adt}.mtx"),
        barcodes_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/{sample_name_adt}.barcodes.txt"),
        genes_file = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/{sample_name_adt}.genes.txt"),
	    MandM = os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS/Materials_and_Methods.txt")
    params:
        os.path.join(ALIGN_OUTPUT_DIR_ADT,"{sample_name_adt}/KALLISTOBUS")
    threads:
        1
    conda:
        CONDA_ENV_QC_ALIGN_GE_ADT
    shell:
        """
        bustools count --genecounts -o {params}/{wildcards.sample_name_adt} -g {TR2GFILE_ADT} -e {input.matrix_file} -t {input.transcripts_file} {input.corrected_file}
        FASTQC_V=$(conda list "fastqc" | grep "^fastqc " | sed -e "s/fastqc *//g" | sed -e "s/ .*//g")
        FASTQSCREEN_V=$(conda list "fastq-screen" | grep "^fastq-screen " | sed -e "s/fastq-screen *//g" | sed -e "s/ .*//g")
        KALLISTO_V=$(conda list "kallisto" | grep "^kallisto " | sed -e "s/kallisto *//g" | sed -e "s/ .*//g")
        KBPYTHON_V=$(conda list "kb-python" | grep "^kb-python " | sed -e "s/kb-python *//g" | sed -e "s/ .*//g")
        BUSTOOLS_V=$(conda list "bustools" | grep "^bustools " | sed -e "s/bustools *//g" | sed -e "s/ .*//g")
        if [[ {SCTECH} = '10xv3' ]];then
        CR="10X Chromium 3′ scRNA-Seq v3 chemistry"
        elif [[ {SCTECH} = '10xv2' ]];then
        CR="10X Chromium 5′ scRNA-Seq v2 chemistry"
        fi
        echo "Raw BCL-files were demultiplexed and converted to Fastq format using bcl2fastq (version 2.20.0.422 from Illumina).
Reads quality control was performed using fastqc (version $FASTQC_V) and assignment to the expected genome species evaluated with fastq-screen (version $FASTQSCREEN_V).
A customized index, with the correspondance between synthetic DNA-transcripts and tagged protein names, was made with the kb-python (version $KBPYTHON_V) wrapper of kallisto. Reads were pseudo-mapped to the customized index with kallisto (version $KALLISTO_V) using its «bus» subcommand and parameters corresponding to the $CR. Barcode correction using whitelist provided by the manufacturer (10X Genomics) and gene-based reads quantification was performed with BUStools (version $BUSTOOLS_V)." > {output.MandM}
        """
