# mixcr_2.1.7_amplicon:1
FROM phusion/baseimage:0.9.19

USER root

# install tools
RUN \
  apt-get update && \
  apt-get install -yq \
    default-jdk \
    unzip \
    perl \
    wget && \
  apt-get clean  

# install mixcr 2.1.7
RUN \
  cd /opt && \
  wget https://github.com/milaboratory/mixcr/releases/download/v2.1.7/mixcr-2.1.7.zip && \
  unzip -o mixcr-2.1.7.zip && \
  rm mixcr-2.1.7.zip && \
  ln -s /opt/mixcr-2.1.7/mixcr /usr/local/bin

#install IMGT library
RUN \
  cd /opt/mixcr-2.1.7/libraries && \
  wget https://github.com/repseqio/library-imgt/releases/download/v1/imgt.201631-4.sv1.json.gz && \
  gunzip imgt.201631-4.sv1.json.gz
  # Download FastQC

# Install FastQC
ADD http://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.11.5.zip /tmp/
RUN cd /usr/local && \
    unzip /tmp/fastqc_*.zip && \
    chmod 755 /usr/local/FastQC/fastqc && \
    ln -s /usr/local/FastQC/fastqc /usr/local/bin/fastqc && \
    rm -rf /tmp/fastqc_*.zip

# setup user for lbgcluster
RUN groupadd -g 1000 lbg \
   && groupadd -g 1026 nextgenseq \
   && groupadd -g 1062 seqgroup \
   && groupadd -g 1063 clinseq \
   && groupadd -g 1075 datasharing \
   && groupadd -g 2650 lbginrc \
   && groupadd -g 2782 lbgseq \
   && groupadd -g 2790 seq-in \
   && groupadd -g 2791 seq-out \
   && groupadd -g 3011 lccc_instrument \
   && groupadd -g 3026 lccc_gpath \
   && groupadd -g 3029 bioinf \
   && groupadd -g 3035 lccc_ram \
   && useradd -u 209755 -g 1000 \
              -G 1026,1062,1063,1075,2650,2782,2790,2791,3011,3026,3029,3035 \
              -s /bin/bash -N -c "Service account for Sequencing" seqware

RUN mkdir -p /home/seqware \
   && chown seqware /home/seqware \
   && chgrp lbg /home/seqware \
   && chmod 775 /home/seqware

# installing R
RUN \
  apt-get update && \
  apt-get -yq install r-base r-base-dev && \
  apt-get -yq install libatlas3-base && \
  Rscript -e 'install.packages("vegan", repos="https://cran.rstudio.com")'

COPY import/ /import/

RUN apt-get clean

USER seqware

# commonly used parameters
ENV CHAINS "ALL"
ENV SPECIES "hsa"
ENV THREADS 1
ENV INPUT_PATH_1 ""
ENV INPUT_PATH_2 ""
ENV OUTPUT_DIR ""
ENV SAMPLE_NAME "no_sample_name_specified"

CMD \
 bash -c 'source /import/run_mixcr.sh \
 --chains "${CHAINS}" \
 --species "${SPECIES}" \
 --threads "${THREADS}" \
 --r1_path "${INPUT_PATH_1}" \
 --r2_path "${INPUT_PATH_2}" \
 --output_dir "${OUTPUT_DIR}" \
 --sample_name "${SAMPLE_NAME}"'

# docker build -t mixcr_2.1.7_amplicon:1 .
