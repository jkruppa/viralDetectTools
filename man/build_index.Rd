% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/build_subset_index.R
\name{build_index}
\alias{build_index}
\title{Build a index for DNA and AA mapper}
\usage{
build_index(dna_set, aa_set, index_dir = NULL, index_name = NULL,
  bowtie = TRUE, pauda = TRUE, star = FALSE, force = FALSE,
  tmp_dir = tempdir())
}
\arguments{
\item{dna_set}{A DNAStringSet to be processed}

\item{aa_set}{A AAStringSet to be porcessed}

\item{index_dir}{The dir of the index (empty)}

\item{index_name}{The name of the index}

\item{bowtie}{Should the Bowtie2 index be build [default = TRUE]}

\item{pauda}{Should the Pauda index be build [default = TRUE]}

\item{star}{Should the Star index be build [default = FALSE]}

\item{force}{Should everything be overwritten [default = FALSE]}

\item{tmp_dir}{File path to the tmp dir}
}
\value{
file.list
}
\description{
The function builds a index of a small subset of sequences
}
\details{
This functions calls Bowtie2, PAUDA and Star to build the DNA
index. The file system is set by the function. As return the path
to index files will be given.
}
\author{
Jochen Kruppa
}
