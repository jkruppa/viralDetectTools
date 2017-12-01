##' Test
##'
##' Test
##' @title Test 
##' @param in_file 
##' @param out_file 
##' @param par_list 
##' @return Test
##' @author Jochen Kruppa
##' @export
artificial_genome_mapping <- function(in_file,
                                      out_file,
                                      par_list
                                      )
{
  talk("Write to ", dirname(out_file))
  ## some checks for file handling later on
  require(tools)
  require(png)
  proc_start_tm <- proc.time()
  ## generate tmp dir if not exists
  if(!file.exists(par_list["tmp_dir"])) {
    talk("Temp dir ", par_list["tmp_dir"], " not found. Will be created...")
    dir.create(par_list["tmp_dir"])
  } else {
    talk("Temp dir ", par_list["tmp_dir"], " found. Will be removed...")
    if(par_list["tmp_dir"] == file.path("/home/temp/"))
      stop("Temp dir is '/home/temp/'! Stop, this not a good idea...")
    unlink(par_list["tmp_dir"], recursive = TRUE)
    talk("Temp dir ", par_list["tmp_dir"], " will be created...")
    dir.create(par_list["tmp_dir"])    
  }
  ## check if mapper and index a coherent  
  if(!str_detect(par_list["genome_index"], par_list["mapper"])){
    stop("par_list['genome_index'] does not fit to the selected mapper in par_list['mapper']!")
  }
  ## check some flags
  if(nchar(file_ext(out_file)) != 0) {
    stop("out_file should have no extension like '.fq'")
  }
  if(length(unlist(in_file)) == 2) {
    par_list["paired"] <- TRUE
  }
  if(nchar(par_list["amino_index"]) == 0) {
    par_list["run_pep_mapping"] <- FALSE
  }
  if(file.exists(str_c(out_file, "_map_pep_list.RDS"))) {
    par_list["run_pep_mapping"] <- FALSE     
  }
  if(file.exists(str_c(out_file, "_map_dna_list.RDS"))) {
    par_list["run_dna_mapping"] <- FALSE     
  }  
  if(file.exists(str_c(out_file, "_consensus.RDS"))) {
    par_list["consensus"] <- FALSE     
  }
  ## if a list of genebank Ids is given, the plot need the consensus
  if(nchar(par_list["plot_id"]) != 0){
    par_list["consensus"] <- TRUE         
  }
  if(any(class(par_list@species_info) == "empty") | any(class(par_list@prot_info) == "empty")) {
    par_list["plot"] <- FALSE
  } else {
    if(tbl_sqlite_check(par_list)) talk("Gene and species information is correct")
  }
  ## begin with trimming
  ## fastq quality control and trimming
  in_file <- fastq_quality_control(inFile = in_file,
                                   tmpDir = par_list["tmp_dir"],
                                   illumninaclip = file.path(dirname(program_list["trimmomatic"]),
                                                             "adapters", "TruSeq3-PE.fa"),
                                   log_file = file.path(par_list["tmp_dir"],
                                                        str_c(basename(out_file), "_trim.log")))
  ## go on here: www.biostars.org/p/165333
  if(par_list["run_dna_mapping"]){
    talk("Start DNA mapping")
    map_dna_list <- map_dna_ref(infile = in_file,
                                outfile = str_c(out_file, ".sam"),
                                par_list)
    talk("Save DNA mapping results...")
    saveRDS(map_dna_list, str_c(out_file, "_map_dna_list.RDS"))
  } else {
    talk("Start DNA mapping -> Stopped due to prior results")
    map_dna_list <- readRDS(str_c(out_file, "_map_dna_list.RDS"))
  }
  ## run PEP mapping
  if(par_list["run_pep_mapping"]){
    talk("Start AMINO mapping")
    map_pep_list <- map_pep_ref(infile = in_file,
                                outfile = str_c(out_file, ".blastx"),
                                par_list)
    talk("Save AMINO mapping results...")
    saveRDS(map_pep_list, str_c(out_file, "_map_pep_list.RDS"))
  } else {
    talk("Start AMINO mapping -> Stopped due to prior results")
    map_pep_list <- readRDS(str_c(out_file, "_map_pep_list.RDS"))
  }
  ## build results xlsx
  talk("Save hits to xlsx")
  ord_df <- ord_findings(map_dna_list, map_pep_list)  
  ## remove some strange references by black_list
  ord_df <- ord_df[!ord_df$genebank_id %in% par_list["black_list"], ]
  genbank_id_desc_df <- collect(select(filter(par_list["species_info"],
                                              genebank_id %in% ord_df$genebank_id),
                                       c(genebank_id, Description))) 
  genbank_id_desc_map <- hashmap(genbank_id_desc_df$genebank_id,
                                 genbank_id_desc_df$Description)
  xlsx_df <- tibble(genebank_id = ord_df$genebank_id,
                    dna_reads = ord_df$count_read,
                    dna_rank = ord_df$rank_dna,
                    amino_reads = as.numeric(ord_df$count_prot),
                    amino_rank = ord_df$rank_pep,
                    description = genbank_id_desc_map[[genebank_id]])
  openxlsx::write.xlsx(xlsx_df, file.path(str_c(out_file, ".xlsx")), row.names = FALSE)
  talk("Generate pylogenetic tree")
  tax_ids <- collect(select(filter(par_list["species_info"],
                                   genebank_id %in% ord_df$genebank_id), tax_id))
  if(par_list["tax"] && nrow(tax_ids) != 0){
    ete2_plot(tax_ids, out_file = out_file,
              pdf_file = str_c(out_file, "_tree.pdf"),
              clean = FALSE)
  } else {
    runCMD(paste("touch", str_c(out_file, "_no_tax_ids_found_tree.pdf")))
  }
  ## clean everything
  unlink(dir0(dirname(out_file), "tax")) ## clean tax files
  unlink(dir0(dirname(out_file), "bam")) ## clean DNA map files
  unlink(dir0(dirname(out_file), "blastx")) ## clean PEP map files
  ## start plotting the results
  if(nrow(ord_df) >= par_list["num_plot"]) {
    ord_df <- ord_df[1:par_list["num_plot"],]
  }
  ## if no plot_ids are given run on findings
  if(nchar(par_list["plot_id"]) == 0) { 
    par_list["plot_id"] <- ord_df$genebank_id
  } 
  if(par_list["consensus"]){
    talk("Generate consensus of reads to reference")
    consensus_list <- get_consensus_df(hits = par_list["plot_id"],
                                       out_file,
                                       par_list)
    ## write consensus_list information to file
    writeXLS(consensus_list[2:6], file.path(str_c(out_file, "_consensus_statistics.xlsx")))
    ## save consensus_list
    saveRDS(consensus_list, str_c(out_file, "_consensus.RDS"))    
  } else {
    talk("Generate consensus of reads to reference -> Stopped due to prior results OR not wanted")
    if(file.exists(str_c(out_file, "_consensus.RDS"))) {
      consensus_list <- readRDS(str_c(out_file, "_consensus.RDS"))
      par_list["consensus"] <- TRUE     
    } else {
      consensus_df <- ""
    }
  }
  ## build the sample info file to get more information on the sample
  sample_info <- build_sample_info(sample_in = in_file,
                                   out_file, par_list, proc_start_tm)
  ## plot the thing  
  if(par_list["plot"]){
    talk("Start generating the mapping pdf")
    mapping_dna_plot(genebank_id = par_list["plot_id"],
                     consensus_df = consensus_list$consensus_df,
                     dna_alignment_df = map_dna_list$alignment_df,
                     pep_alignment_df = map_pep_list$alignment_df,
                     aa_info_df = par_list["prot_info"],
                     viral_info_df = par_list["species_info"],
                     sample_info = sample_info,
                     pdf_file = ifelse(length(par_list["pdf_file"]) == 0,
                                       str_c(out_file, ".pdf"), par_list["pdf_file"]),
                     par_list)
  } else {
    talk("Start generating the mapping pdf -> Stopped, not wanted")
  }
  ## clean the temp folder
  gc()
  if(par_list["clean"]) unlink(dir0(par_list["tmp_dir"]))
  talk("Finished\n")
}
