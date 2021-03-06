##' The function draws randomly reads from a sequence. Linux only due
##' to cat commands.
##'
##' The function draws in parallel from a inital seqeunce a given
##' nuber of paired reads. The reads are saved temporal in the tmp
##' folder definied by \code{\link{set_par_list}}.
##' @title Generates (decoy) reads from a sequence
##' @param decoy_seq Sequence to draw the reads from as DNAStringSet
##' @param paired Should the reads be paired? [default = TRUE]
##' @param read_num How many reads should be generated? [default =
##'   10000]
##' @param read_length How long should the reads be? [default = 50]
##' @param read_gap How large should be the gap between paired reads?
##'   [default = 50]
##' @param split How many processes should be run in parallel?
##'   [default = 10]
##' @param par_list Parameter given by the par_list(), see
##'   \code{\link{set_par_list}}
##' @return NULL
##' @author Jochen Kruppa
##' @export
generate_decoy_reads <- function(decoy_seq,
                                 paired = TRUE,
                                 read_num = 10000,
                                 read_length = 50,
                                 read_gap = 50,
                                 split = 10,
                                 par_list) {
  ## build the files
  if(paired){
    tmp_files <- list("R1" = tempfile(pattern = str_c(names(decoy_seq), "_R1_"),
                                      tmpdir = par_list["tmp_dir"], fileext = ".fq"),
                      "R2" = tempfile(pattern = str_c(names(decoy_seq), "_R2_"),
                                      tmpdir = par_list["tmp_dir"], fileext = ".fq"))
  } else {
    tmp_files <- list("R1" = tempfile(pattern = str_c(names(decoy_seq), "_R1_"),
                                      tmpdir = par_list["tmp_dir"], fileext = ".fq"))    
  }
  ## generate the reads
  read_chunks <- chunks(1:read_num, read_num/split)
  read_chunks_files <- llply(1:split, function(i) {
    c("R1" = tempfile(str_c("R1_", str_pad(i, 3, pad = "0"), "_"),
                      tmpdir = par_list["tmp_dir"], fileext = ".fq"),
      "R2" = tempfile(str_c("R2_", str_pad(i, 3, pad = "0"), "_"),
                      tmpdir = par_list["tmp_dir"], fileext = ".fq"))
  })
  l_ply(seq_along(read_chunks), function(chunk_iter){
    l_ply(read_chunks[[chunk_iter]], function(...) {
      generate_read(decoy_seq,
                    files = read_chunks_files[[chunk_iter]],
                    paired,
                    read_length,
                    read_gap)
    })
  }, .parallel = TRUE)
  ## paste the reads together
  if(paired){
    cat_cmd <- paste("find", par_list["tmp_dir"], "-type f -name 'R1*.fq' -print0 | sort -z | xargs -r0 cat >",
                     tmp_files[["R1"]])
    runCMD(cat_cmd)
    cat_cmd <- paste("find", par_list["tmp_dir"], "-type f -name 'R2*.fq' -print0 | sort -z | xargs -r0 cat >",
                     tmp_files[["R2"]])
    runCMD(cat_cmd)
    runCMD(paste("gzip", tmp_files[["R1"]]))
    runCMD(paste("gzip", tmp_files[["R2"]]))
  } else {
    cat_cmd <- paste("find", par_list["tmp_dir"], "-type f -name 'R1*.fq' -print0 | sort -z | xargs -r0 cat >",
                     tmp_files[["R1"]])
    runCMD(cat_cmd)
    runCMD(paste("gzip", tmp_files[["R1"]]))
  }
  ## clean the inter files
  unlink(unlist(read_chunks_files))
}

##' A internal function of \code{\link{generate_decoy_reads}}. Linux only.
##'
##' This function call generates a set or one sequence read of a given
##' length from a inital sequence.
##' @title Generates a _single_ read from a sequence
##' @param decoy_seq Sequence as DNAStringSet
##' @param files File path to the output file(s)
##' @param paired Logical, should the reads be paired? [default =
##'   TRUE]
##' @param read_length Numeric, read length
##' @param read_gap If paired, how large should be the gap?
##' @return NULL
##' @author Jochen Kruppa
##' @export
generate_read <- function(decoy_seq,
                          files,
                          paired = TRUE,
                          read_length,
                          read_gap = 50
                          ) {
  ## check is paired reads are needed...
  ## distance of the paired reads
  read_dist <- rpois(1, read_gap)
  ## read total range
  read_range <- 2*read_length + read_dist
  max_value <- width(decoy_seq) - read_range
  ## get the read start positions
  start_pos_R1 <- sample(1:max_value, 1)
  start_pos_R2 <- start_pos_R1 + read_length + read_dist
  ## R1 is easy...
  R1 <- subseq(decoy_seq, start_pos_R1, start_pos_R1 + read_length - 1)
  ## R2 with the reverse sequence and the complement bases
  R2_pre <- subseq(decoy_seq, start_pos_R2, start_pos_R2 + read_length - 1)
  R2 <- complement(Biostrings::reverse(R2_pre)) ## complement of the sequence
  ## get better names
  R1_q <- ShortReadQ(sread = R1,
                     quality = BStringSet(str_c(rep("I", width(R1)), collapse = "")),
                     id = BStringSet(str_c("R1", "_", names(decoy_seq))))
  R2_q <- ShortReadQ(sread = R2,
                     quality = BStringSet(str_c(rep("I", width(R2)), collapse = "")),
                     id = BStringSet(str_c("R2", "_", names(decoy_seq))))
  if(paired){
    writeFastq(R1_q, files[["R1"]], compress = FALSE, mode = "a")
    writeFastq(R2_q, files[["R2"]], compress = FALSE, mode = "a")
  } else {
    writeFastq(R1_q, files[["R1"]], compress = FALSE, mode = "a")
  }
}
