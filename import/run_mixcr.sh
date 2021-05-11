#!/bin/sh

while [ $# -gt 0 ]; do
  case "$1" in
    --chains=*)
      CHAINS="${1#*=}"
      ;;
    --species=*)
      SPECIES="${1#*=}"
      ;;
    --threads=*)
      THREADS="${1#*=}"
      ;;
    --r1_path=*)
      INPUT_PATH_1="${1#*=}"
      ;;
    --r2_path=*)
      INPUT_PATH_2="${1#*=}"
      ;;
    --output_dir=*)
      OUTPUT_DIR="${1#*=}"
      ;;
    --sample_name=*)
      SAMPLE_NAME="${1#*=}"
      ;;
  esac
  shift
done

echo "CHAINS: ${CHAINS}"
echo "SPECIES: ${SPECIES}"
echo "THREADS: ${THREADS}"
echo "INPUT_PATH_1: ${INPUT_PATH_1}"
echo "INPUT_PATH_2: ${INPUT_PATH_2}"
echo "OUTPUT_DIR: ${OUTPUT_DIR}"
echo "SAMPLE_NAME: ${SAMPLE_NAME}"

FILE_PREFIX=${SAMPLE_NAME}_

cd ${OUTPUT_DIR}
alignment="${FILE_PREFIX}alignment.vdjca"
alignment_log="${FILE_PREFIX}alignment_log.txt"
alignment_txt="${FILE_PREFIX}alignment.txt"
clone_assembly="${FILE_PREFIX}clones.clns"
clone_log="${FILE_PREFIX}clone_log.txt"
clone_txt="${FILE_PREFIX}clones.txt"
index_file="${FILE_PREFIX}index_file"
extended_alignment="${FILE_PREFIX}extended_alignment.vdjca"
aligned_r1="${FILE_PREFIX}aligned_r1.fastq"
aligned_r2="${FILE_PREFIX}aligned_r2.fastq"
unaligned_r1="${FILE_PREFIX}unaligned_r1.fastq"
unaligned_r2="${FILE_PREFIX}unaligned_r2.fastq"

echo "Running MiXCR align..."
# temp work around for an exception produced with -r ${alignment_log} \
#  is to touch the file first
# touch ${alignment_log}
mixcr align -f \
  --write-all \
  --save-reads \
  --library imgt \
  --not-aligned-R1 ${unaligned_r1} \
  --not-aligned-R2 ${unaligned_r2} \
  -r ${alignment_log} \
  -c ${CHAINS} \
  -s ${SPECIES} \
  -t ${THREADS} \
  ${INPUT_PATH_1} ${INPUT_PATH_2} \
  ${alignment}


echo "Running MiXCR assemble..."
# touch ${clone_log}
mixcr assemble -f \
  --index ${index_file} \
  -r ${clone_log} \
  -t ${THREADS} \
  ${alignment} ${clone_assembly}

echo "Running MiXCR exportAlignments..."
mixcr exportAlignments -f \
  -cloneIdWithMappingType ${index_file} \
  -readId -sequence -quality -targets  -aaFeature CDR3 \
  ${alignment} \
  ${alignment_txt}

echo "Running MiXCR exportClones..."
# -c --chains is the new way to get the clone fractions
mixcr exportClones -f -chains \
  --filter-out-of-frames \
  --filter-stops \
  -cloneId \
  -count \
  -nFeature CDR3 -qFeature CDR3 -aaFeature CDR3 \
  -vHit -dHit -jHit \
  -vHitsWithScore -dHitsWithScore -jHitsWithScore \
  ${clone_assembly} \
  ${clone_txt}

echo "Grabbing data from MiXCR logs..."
Rscript /import/rscripts/extract_mixcr_align_stats.R ${alignment_log} align_stats.csv
Rscript /import/rscripts/extract_mixcr_clone_assembly_stats.R ${clone_log} clone_stats.csv
align_columns=$(head -n 1 align_stats.csv)
align_stats=$(sed '2q;d' align_stats.csv)
clone_columns=$(head -n 1 clone_stats.csv)
clone_stats=$(sed '2q;d' clone_stats.csv)
mixcr_columns="Sample_ID,${clone_columns},${align_columns}"
mixcr_qc="${SAMPLE},${clone_stats},${align_stats}"
echo "${mixcr_columns}" > mixcr_qc.csv
echo "${mixcr_qc}" >> mixcr_qc.csv

echo "Computing diversity metrics..."
Rscript /import/rscripts/process_mixcr.R $SAMPLE_NAME $clone_txt mixcr_stats.csv

echo "Make fastq file with only the aligned reads..."
# ow=t (overwrite) Overwrites files that already exist.
# include=f Set to 'true' to include the filtered names rather than excluding them.
# -Xmx2g \ removed

/import/bbmap/filterbyname.sh \
  ow=t \
  in=${INPUT_PATH_1} \
  in2=${INPUT_PATH_2} \
  out=${aligned_r1} \
  out2=${aligned_r2} \
  names=${unaligned_r1} \
  include=f

echo "Running FastQC on aligned reads..."
fastqc --output="." ${aligned_r1}
fastqc --output="." ${aligned_r2}

chmod 666 *

