#!/usr/bin/env bash

# AWS Lambda provisioning script for Python.
# Creates and deploys package or runs it inside Docker container.
# Prerequisites:
#   - main Lambda code in 'index.py' file
#   - handler method called 'handler'
#   - required packages in 'requirements.txt'

# changes back files ownership after they were created by root in docker container
# root is needed to install dependencies
# running without it in some automation tools will fail
function copy_ownership() {
    SOURCE=$1
    TARGET=$2
    SOURCE_UID=$(stat -c %u ${SOURCE})
    SOURCE_GID=$(stat -c %g ${SOURCE})
    chown -R ${SOURCE_UID}:${SOURCE_GID} ${TARGET}
}

# creates deployment package and sends it to S3
function deploy_host_part() {
    echo "===>   Preparing ${RUNTIME} Lambda package: ${FUNCTION_NAME}"
    # copy files that must be added to package
    mkdir -p ${HOST_WORKING_DIR}/package/
    cp ${HOST_SOURCE_DIR}/lambda.sh ${HOST_WORKING_DIR}/
    cp ${HOST_SOURCE_DIR}/requirements.txt ${HOST_SOURCE_DIR}/index.py ${HOST_WORKING_DIR}/package/
    # any other copying or file modifications goes here
    # they all should be put in ${HOST_WORKING_DIR}/package/ dir

    DOCKER_DIR=$(echo ${DOCKER_DIR} | sed 's/://')
    DOCKER_DIR="${DOCKER_DIR}/.dist"

    echo "===>   Mounting Docker dir: ${DOCKER_DIR}"
    # run container_part
    docker run \
        --rm \
        --volume /${DOCKER_DIR}:${CONT_INSTALL_DIR} \
        --workdir ${CONT_INSTALL_DIR} \
        lambci/lambda:build-${RUNTIME} ./lambda.sh deploy ${FUNCTION_NAME} ${RUNTIME} ${S3_BUCKET} ${S3_KEY}

    copy_ownership ${HOST_SOURCE_DIR} ${HOST_WORKING_DIR}
    if [[ ${S3_BUCKET} != "" && ${S3_KEY} != "" ]]; then
        echo "===>   Uploading to: s3://${S3_BUCKET}/${S3_KEY}"
        FILEBASE64SHA256=`openssl dgst -sha256 -binary ${HOST_WORKING_DIR}/${FUNCTION_NAME}.zip | openssl base64`
        TAG_SET="TagSet=[{Key=filebase64sha256,Value=${FILEBASE64SHA256}}]"
        aws s3 cp ${HOST_WORKING_DIR}/${FUNCTION_NAME}.zip s3://${S3_BUCKET}/${S3_KEY} --profile ${AWS_PROFILE}
        aws s3api put-object-tagging --bucket ${S3_BUCKET} --key ${S3_KEY} --tagging ${TAG_SET} --profile ${AWS_PROFILE}
    fi
    echo "===>   Finished preparing Lambda: ${FUNCTION_NAME}"
}

# installs native libraries for Lambda
function deploy_container_part() {
    # install requirements and copy files from source/ dir
    mkdir -p ${CONT_WORKING_DIR}
    cd ${CONT_WORKING_DIR}
    echo "===>   Installing requirements"
    pip install --no-cache-dir -t . -r ${CONT_INSTALL_DIR}/package/requirements.txt
    find . -type f -name "*.py[co]" -exec rm {} +
    mv ${CONT_INSTALL_DIR}/package/* .
    echo "===>   Creating package ${FUNCTION_NAME}.zip"
    zip --recurse-paths ${FUNCTION_NAME}.zip * >>/dev/null
    mv ${FUNCTION_NAME}.zip ${CONT_INSTALL_DIR}/
}

# runs function from package
function run_host_part() {
    echo "===>   Running ${RUNTIME} Lambda: ${FUNCTION_NAME}"

    DOCKER_DIR=$(echo ${DOCKER_DIR} | sed 's/://')

    echo "===>   Mounting Docker dir: ${DOCKER_DIR}"
    # run container_part
    echo ${EVENT} | docker run \
        --rm \
        --user $(id -u):$(id -g) \
        --volume /${DOCKER_DIR}:${CONT_TASK_DIR} \
        --env SOME_VAR=${SOME_VAR} \
        --env DOCKER_LAMBDA_USE_STDIN=1 \
        --interactive \
        lambci/lambda:${RUNTIME} index.handler

    echo "===>   Finished running Lambda: ${FUNCTION_NAME}"
}

# common parameters
ACTION=$1
FUNCTION_NAME=$2
RUNTIME=$3
# parameters for deployment
AWS_PROFILE=$4
S3_BUCKET=$5
S3_KEY=$6
# parameters for running
EVENT=$4
SOME_VAR=$5

# main execution
CONT_WORKING_DIR=/tmp/work
CONT_TASK_DIR=/var/task
CONT_INSTALL_DIR=/tmp/install
HOST_SOURCE_DIR=$(dirname "$(readlink -f "$0")")
HOST_WORKING_DIR=${HOST_SOURCE_DIR}/.dist

# workaround for WSL
grep -qE "(Microsoft|WSL)" /proc/version
if [[ $? == 0 ]]; then
    MOUNT_DIR=$(df | grep 'C:' | awk '{print $6}' | sed 's|\/|\\/|g')
	DOCKER_DIR=$(pwd | sed "s|${MOUNT_DIR}|C:|g")
else
    DOCKER_DIR=$(pwd)
fi

if [[ ${ACTION} == "deploy" ]]; then
    if [[ ${PWD} == ${CONT_INSTALL_DIR} ]]; then
        deploy_container_part
    else
        deploy_host_part
    fi
else
    if [[ ${PWD} != ${CONT_INSTALL_DIR} ]]; then
        run_host_part
    fi
fi
