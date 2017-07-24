#!/bin/bash -e

#############################################
#
# Global Variable
############################################
DOCKER_NAME="pipeline/image-service"
OPERATION=""

#########################################
#
#  Usage
#
#########################################
Usage(){
    echo "function: this script is used to deploy image-service within docker"
    echo "usage: $0 [options] [arguments]"
    echo "  options:"
    echo "    -h     : give this help list"
    echo "    cleanup: remove the running image-service docker container and images"
    echo "    deploy : build a image with image-service and run it"
    echo "    mandatory arguments:"
    echo "      -w, --WORKSAPCE: the directory of workspace( where the code will be cloned to and staging folder), it's required"
    echo "      -p, --SUDO_PASSWORD: password of current user which has sudo privilege, it's required."
    echo "      -d, --REPO_DIR: The directory of image service source code"
}


##############################################
#
# Remove docker images after test
#
###########################################
cleanUpDockerImages(){
    set +e
    local to_be_removed="$(echo $SUDO_PASSWORD |sudo -S docker images ${DOCKER_NAME} -q)  \
                         $(echo $SUDO_PASSWORD |sudo -S docker images pipeline/image-service-base -q) \
                         $(echo $SUDO_PASSWORD |sudo -S docker images -f "dangling=true" -q )"
    # remove ${DOCKER_NAME} image,  pipeline/image-service-base and <none>:<none> images
    if [ ! -z "${to_be_removed// }" ] ; then
         echo $SUDO_PASSWORD |sudo -S docker rmi $to_be_removed
    fi
    set -e
}

##############################################
#
# Remove docker instance which are running
#
###########################################
cleanUpDockerContainer(){
    set +e
    local docker_name_key=$1
    local running_docker=$(echo $SUDO_PASSWORD |sudo -S docker ps -a |grep "$1" |awk '{print $1}')
    if [ "$running_docker" != "" ]; then
         echo $SUDO_PASSWORD |sudo -S docker stop $running_docker
         echo $SUDO_PASSWORD |sudo -S docker rm   $running_docker
    fi
    set -e
}

######################################
#
# Clean Up runnning docker instance
#
#####################################
cleanupDockers(){
    echo "CleanUp Dockers ..."
    set +e
    cleanUpDockerContainer "${DOCKER_NAME}"
    cleanUpDockerImages
    set -e
}

############################################
#
# Clean Up if you want to stop image service docker and recover services
#
###########################################
cleanUp(){
    set +e
    echo "*****************************************************************************************************"
    echo "Start to clean up environment: stopping running containers, starting service mongodb and rabbitmq-server"
    echo "*****************************************************************************************************"
    cleanupDockers
    netstat -ntlp
    echo "*****************************************************************************************************"
    echo "End to clean up environment: stopping running containers, starting service mongodb and rabbitmq-server"
    echo "*****************************************************************************************************"
    set -e
}

###################################
#
# Build docker and run it
#
#################################
dockerUp(){
    echo "*****************************************************************************************************"
    echo "Start to build and run image service docker"
    echo "*****************************************************************************************************"
    mkdir -p  $WORKSPACE/build-logs
    pushd $REPO_DIR
    echo $SUDO_PASSWORD |sudo -S docker build -t $DOCKER_NAME .
    echo $SUDO_PASSWORD |sudo -S docker run --privileged --net=host -v /etc/localtime:/etc/localtime:ro -t $DOCKER_NAME > $WORKSPACE/build-logs/image-service.log &
    popd
    echo "*****************************************************************************************************"
    echo "End to build and run image service docker"
    echo "*****************************************************************************************************"
}

##############################################
#
# Check the API of image-service is accessable
#
#############################################
waitForAPI() {
    echo "*****************************************************************************************************"
    echo "Try to access the image service API"
    echo "*****************************************************************************************************"
    timeout=0
    maxto=60
    set +e
    url="localhost:7070/images"
    while [ ${timeout} != ${maxto} ]; do
        wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 1 --continue ${url}
        if [ $? = 0 ]; then
          break
        fi
        sleep 10
        timeout=`expr ${timeout} + 1`
    done
    set -e
    if [ ${timeout} == ${maxto} ]; then
        echo "Timed out waiting for image service (duration=`expr $maxto \* 10`s)."
        exit 1
    fi
    echo "*****************************************************************************************************"
    echo "Image service API is accessable"
    echo "*****************************************************************************************************"
}


##############################################
#
# deploy image service 
#
#############################################
deploy(){
    # Build docker image and run it
    dockerUp
    # Check the image service API is accessable
    waitForAPI
}

###################################################################
#
#  Parse and check Arguments
#
##################################################################
parseArguments(){

    while [ "$1" != "" ]; do
        case $1 in
            -w | --WORKSPACE )              shift
                                            WORKSPACE=$1
                                            ;;
            -d | --REPO_DIR )               shift
                                            REPO_DIR=$1
                                            ;;
            -p | --SUDO_PASSWORD )          shift
                                            SUDO_PASSWORD=$1
                                            ;;
            * )                             Usage
                                            exit 1
        esac
        shift
    done

    if [ ! -n "${WORKSPACE}" ] && [ ${OPERATION,,} != "cleanup" ]; then
        echo "The argument -w|--WORKSPACE is required"
        exit 1
    else
        if [ ! -d "${WORKSPACE}" ]; then
            mkdir -p ${WORKSPACE}
        fi
    fi

    if [ ! -n "${SUDO_PASSWORD}" ]; then
        echo "[Error]Arguments -p|--SUDO_PASSWORD is required"
        Usage
        exit 1
    fi
    
    if [ ! -n "${REPO_DIR}" ] && [ ${OPERATION,,} != "cleanup" ]; then
        echo "[Error]Arguments -d | --REPO_DIR is required"
        Usage
        exit 1
    fi

}


########################################################
#
# Main
#
######################################################
OPERATION=$1
case "$1" in
  cleanUp|cleanup)
      shift
      parseArguments $@
      cleanUp
  ;;

  deploy)
      shift
      parseArguments $@
      deploy
  ;;

  -h|--help|help)
    Usage
    exit 0
  ;;

  *)
    Usage
    exit 1
  ;;

esac
