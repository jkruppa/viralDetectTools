% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/map_pep_ref.R
\name{map_pep_ref}
\alias{map_pep_ref}
\title{Amino mapping function}
\usage{
map_pep_ref(infile, outfile, par_list)
}
\arguments{
\item{infile}{File path to the fastq file, better controlled by
parameter given by the par_list(), see
\code{\link{set_par_list}}}

\item{outfile}{File path to the results dir}

\item{par_list}{Parameter given by the par_list(), see
\code{\link{set_par_list}}}
}
\value{
pep_alignment_df list
}
\description{
This function calls PANDAseq and PAUDA for mapping the translated DNA reads
}
\details{
The function is the mapping control function for the AA
mapping. Most importantly, paired reads are merged by PAUDAseq
first. The mapping and translation of the sequence reads to amino
reads is done by PAUDA. Finally, the blastx output is parsed by
\code{\link{get_pauda_hits}}.
}
\examples{
data(NHS_10001_map_aa_list)
}
\author{
Jochen Kruppa
}
