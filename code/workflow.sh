#!/usr/bin/env bash

#set -x -e


# Service environment
WORKFLOW=$(dirname $(readlink -f "$0"))
# WORKER_DIR="${PWD}"
WORKER_DIR="/home/worker"
IN_DIR="${WORKER_DIR}/workDir/inDir"
OUT_DIR="${WORKER_DIR}/workDir/outDir"
WPS_PROPS="${WORKER_DIR}/workDir/WPS-INPUT.properties"
PROC_DIR="${WORKER_DIR}/procDir"
TIMESTAMP=$(date --utc +%Y%m%d_%H%M%SZ)

eval "$(micromamba shell hook --shell=bash)"
micromamba activate sen_et_env
echo "Python path: $(which python)"
python -V

function export_json_to_env () {
    INPUT_FILE="${1}"
    while IFS=$'\t\n' read -r LINE; do
        export "${LINE}"
    done < <(
        <"${INPUT_FILE}" jq \
            --compact-output \
            --raw-output \
            --monochrome-output \
            --from-file \
            <(echo 'to_entries | map("\(.key)=\(.value)") | .[]')
    )
}

# Extract the username and password from the credentials.json file using jq
PATH_CREDENTIALS="${IN_DIR}/path_to_credentials/credentials.json"
ls -l $PATH_CREDENTIALS

# Ensure the path_to_credentials environment variable is set
if [ -z "$PATH_CREDENTIALS" ]; then
    echo "Error: The path_to_credentials environment variable is not set."
    exit 1
fi

# Check if the credentials file exists
if [ ! -f "$PATH_CREDENTIALS" ]; then
    echo "Error: The credentials file does not exist at the specified path: $PATH_CREDENTIALS"
    exit 1
fi

export_json_to_env "${IN_DIR}/path_to_credentials/credentials.json"

python /home/worker/processor/download_esacci_lc.py
echo "Moving landCover file to root folder"
ls -lh /tmp
mv /tmp/ESACCI-LC-L4-LCCS-Map-300m-P1Y-2022-v2.1.1/*.nc /root/app/steps/add_landcover/ESACCI-LC-L4-LCCS-Map-300m-P1Y-2022-v2.1.1.nc
chmod 644 /root/app/steps/add_landcover/ESACCI-LC-L4-LCCS-Map-300m-P1Y-2022-v2.1.1.nc
echo "Check if Land Cover File is in folder"
ls -lh /root/app/steps/add_landcover/


mkdir -p ${PROC_DIR}

# Input parameters available as shell variables
source ${WPS_PROPS}

export GDA_AGRI_STEPS=initialize_input_output,ecmwf_data_download,s2_preprocessing,s3_preprocessing,add_dem,add_landcover,s2_sen_et_processing,s3_sen_et_processing,s3_mosaicking,convert_dim_output_to_tiff,archive_results
export GDA_AGRI_CONFIG=/root/config/config_docker.yml
export GDA_AGRI_LOG_LEVEL=DEBUG 
export GDA_AGRI_JOB_ID='fake_value'
export GDA_AGRI_PIPELINE_ID='fake_value'

S2_INPUT_FOLDER=${IN_DIR}/s2_input
S3_INPUT_FOLDER=${IN_DIR}/s3_input
PVC_INPUT_PATH=${IN_DIR}/gda
PVC_INPUT_PATH_ZIP=${IN_DIR}/zip

mkdir -p ${PVC_INPUT_PATH}
GDA_S2Input=${PVC_INPUT_PATH}/s2_input
GDA_S3Input=${PVC_INPUT_PATH}/s3_input

mkdir -p ${PVC_INPUT_PATH_ZIP}
GDA_S2Input_zip=${PVC_INPUT_PATH_ZIP}/s2_input
GDA_S3Input_zip=${PVC_INPUT_PATH_ZIP}/s3_input
mkdir -p ${GDA_S2Input_zip}
mkdir -p ${GDA_S3Input_zip}


removeSchema(){

	local sentinel="${1%:*}"	
	echo ${1#"${sentinel}://"}
}

removeExt(){
	echo filename="${1%.*}"
}

checkParameters (){
	moreParamsS2=0
	echo ${s2_input} |  grep ',' > /dev/null
	if [ $? -eq 0 ]
	then 
		moreParamsS2=1
	fi

	moreParamsS3=0
	echo ${s3_input} |  grep ','  > /dev/null
	if [ $? -eq 0 ]
	then 
		moreParamsS3=1
	fi
}


moveSentineXSingle(){

    echo "Starting moveSentinelXSingle"
	local URL_NOPRO=$(removeSchema ${1})
	URL_NOPRO=$(echo "${URL_NOPRO}"| sed 's/\///g')

	local agri_folder=${2}/${URL_NOPRO}
	
	mkdir -p ${agri_folder}
	cp -r ${3}/* ${agri_folder}/
	cd ${2}
	zip -r ${URL_NOPRO}.zip ${URL_NOPRO}
	mv ${URL_NOPRO}.zip ${4}/
	cd -
}

  
moveSentineXMulti(){	

	local extension
	local folder
	local inFolder
	local outFolder

	IFS=',' read -r -a array <<< "${1}"
	for element in "${array[@]}"
	do	
      
        echo "Starting moveSentinelXMulti"
        echo ${element}
        local URL_NOPRO=$(removeSchema ${element})
        URL_NOPRO=$(echo "${URL_NOPRO}"| sed 's/\///g')

        local agri_folder=${2}/${URL_NOPRO}
        
        mkdir -p ${agri_folder}
        cp -r ${3}/${URL_NOPRO}/* ${agri_folder}/
        cd ${2}
        zip -r ${URL_NOPRO}.zip ${URL_NOPRO}
        mv ${URL_NOPRO}.zip ${4}/
        cd -
	done	
}

checkParameters

echo ${moreParamsS2}
echo ${moreParamsS3}

if [ ${moreParamsS2} -eq 0 ]
then
  moveSentineXSingle ${s2_input} ${GDA_S2Input} ${S2_INPUT_FOLDER} ${GDA_S2Input_zip}
else
  moveSentineXMulti ${s2_input} ${S2_INPUT_FOLDER} ${GDA_S2Input}
fi

if [ ${moreParamsS3} -eq 0 ]
then
 moveSentineXSingle ${s3_input}  ${GDA_S3Input}  ${S3_INPUT_FOLDER}	${GDA_S3Input_zip}
else
 moveSentineXMulti ${s3_input} ${GDA_S3Input} ${S3_INPUT_FOLDER}	${GDA_S3Input_zip}
fi

ls -ltR ${PVC_INPUT_PATH_ZIP}
#ls -ltR ${PVC_INPUT_PATH}

mkdir -p ${OUT_DIR}/zip
cp 	/home/worker/workDir/inDir/zip/s3_input/* ${OUT_DIR}/zip
cp 	/home/worker/workDir/inDir/zip/s2_input/* ${OUT_DIR}/zip
ls -ltR ${PVC_INPUT_PATH_ZIP}

export GDA_AGRI_OUTPUT_PATH=${PROC_DIR}
export GDA_AGRI_INPUT_PATH="/home/worker/workDir/inDir/zip"

/bin/bash --login -c /entrypoint.sh || exit $?

if [[ $? -ne 0 ]]
then
  echo "GDA Evapotranspiration processor failed"
  exit 1
fi

mkdir -p "${OUT_DIR}/output_daily_et"
mkdir -p "${OUT_DIR}/output_lst"
mkdir -p "${OUT_DIR}/output_s2_quality"
mkdir -p "${OUT_DIR}/output_s3_quality"

cd "${GDA_AGRI_OUTPUT_PATH}"

find . -path "*archive_results*" -name "*.tif" | while read -r file; do
    filename=$(basename "$file")

    case "$filename" in
        *daily_et*)
            cp "$file" "${OUT_DIR}/output_daily_et/"
            ;;
        *lst*)
            cp "$file" "${OUT_DIR}/output_lst/"
            ;;
        *s2_quality*)
            cp "$file" "${OUT_DIR}/output_s2_quality/"
            ;;
        *s3_quality*)
            cp "$file" "${OUT_DIR}/output_s3_quality/"
            ;;
        *)
            echo "Unknown file type: $filename"
            ;;
    esac
done
