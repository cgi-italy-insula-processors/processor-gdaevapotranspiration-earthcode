FROM core.harbor.dev.eoss-cloud.it/gdap/gdap:1.0.8

RUN apt-get update && apt-get install -y jq

ENV GDA_AGRI_OUTPUT_PATH="/home/worker/workDir/outDir"
ENV GDA_AGRI_INPUT_PATH="/home/worker/workDir/inDir/zip"

RUN ls /
RUN mkdir -p /home/worker/processor
COPY * /home/worker/processor/

ENTRYPOINT ["/home/worker/processor/workflow.sh"]