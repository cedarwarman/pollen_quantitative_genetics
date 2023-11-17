/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    k-mers-based GWAS workflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params.samplesheet = "/home/u16/cedar/git/pollen_quantitative_genetics/nextflow/samplesheets/test_samplesheet.tsv"
params.outdir = "." // Defaults to where the script is run

log.info """\
    NF - K - M E R S - G W A S   P I P E L I N E
    ============================================
    samplesheet  : ${params.samplesheet}
    outdir       : ${params.outdir}
    """
    .stripIndent()

/*
 * Setting up the input channel with metadata
*/

Channel
    .fromPath(params.samplesheet)
    .splitCsv(header: true, sep: '\t', strip: true)
    .map { row ->
        tuple(row.accession_id, [file: file(row.fq), paired_end: row.paired_end, srr_id: row.srr_id])
    }
    .groupTuple(by: [0])
//    .view { "Grouped data: $it" }  // Debugging statement
    .set { samples_meta_ch }

/*
 * Processes
*/

// Make files of file paths for kmc input
process MAKE_READ_PATHS_FILE {
    tag "MAKE_READ_PATHS_FILE on ${accession_id}"

    input:
    tuple val(accession_id), val(file_maps)

    output:
    tuple val(accession_id), val(file_maps), path("${task.workDir}/file_paths_${accession_id}.txt")

    exec:
    def file_list="${task.workDir}/file_paths_${accession_id}.txt"
    new File(file_list).withWriter { writer ->
        file_maps.each { writer.println(it.file) }
    }
}

// First kmc run with canonization
process KMC_COUNT_ONE_CANONIZED {
    conda "/home/u16/cedar/git/pollen_quantitative_genetics/nextflow/config/mamba/kmc.yaml"

    tag "KMC_COUNT_ONE_CANONIZED on ${accession_id}"

    publishDir "${params.outdir}/results/kmc_count_one_canonized/${accession_id}", mode: 'symlink'

    input:
    tuple val(accession_id), val(file_maps), path(read_paths_file)

    output:
    path "output_kmc_canon_${accession_id}*"

    script:
    println("Processing accession: ${accession_id}, file list: ${read_paths_file}") // debugging
    // Run kmc command
    """
    kmc -t${task.cpus} -k31 -ci2 @${read_paths_file} output_kmc_canon_${accession_id} ./ 1> kmc_canon.1 2> kmc_canon.2
    """
}


/*
 * Workflow
*/

workflow {
    read_paths_ch = MAKE_READ_PATHS_FILE(samples_meta_ch)
    KMC_COUNT_ONE_CANONIZED(read_paths_ch)
}

workflow.onComplete {
    log.info ( workflow.success ? "\nSuccess" : "Failure" )
}

