#!/bin/bash -ex

#############################################
#
# Usage
############################################
Usage(){
    set +x
    echo "Function: This script is used to set up environment for FIT and run FIT."
    echo "Usage: $0 [OPTIONS]"
    echo "  OPTIONS:"
    echo "    Mandatory options:"
    echo "      -w, --WORKSPACE: The directory of workspace( where the code will be cloned to and staging folder), it's required"
    echo "      -p, --SUDO_PASSWORD: password of current user which has sudo privilege, it's required."
    echo "    Optional options:"
    echo "      -g, --TEST_GROUP: test group of FIT, such as imageservice, smoke"
    echo "      -r, --RACKHD_DIR: The directory of repository RackHD"
    echo "                       If it's not provided, the script will clone the latest repository RackHD under $WORKSPACE"
    set -x
}


#############################################
#
#  Create the virtual env for FIT  
#
############################################
setupVirtualEnv(){
    pushd ${RACKHD_DIR}/test
    virtual_env_name=FIT
    rm -rf .venv/$virtual_env_name
    ./mkenv.sh $virtual_env_name
    source myenv_$virtual_env_name
    popd
}

####################################
#
# 1. Modify FIT config files , to  using actual DHCP Host IP instead of 172.31.128.1
#
##################################
setupTestsConfig(){
    echo "SetupTestsConfig ...replace the 172.31.128.1 IP in test configs with actual DHCP port IP"
    RACKHD_DHCP_HOST_IP=$(ifconfig | awk '/inet addr/{print substr($2,6)}' |grep 172.31.128)
    if [ "$RACKHD_DHCP_HOST_IP" == "" ]; then
         echo "[Error] There should be a NIC with 172.31.128.xxx IP in your OS."
         exit -2
    fi
    pushd ${RACKHD_DIR}/test/config
    sed -i "s/\"username\": \"vagrant\"/\"username\": \"${USER}\"/g" credentials_default.json
    sed -i "s/\"password\": \"vagrant\"/\"password\": \"$SUDO_PASSWORD\"/g" credentials_default.json
    popd
    pushd ${RACKHD_DIR}/test
    find ./ -type f -exec sed -i -e "s/172.31.128.1/${RACKHD_DHCP_HOST_IP}/g" {} \;
    popd
}

####################################
#
# Collect the test report
#
##################################
collectTestReport()
{
    mkdir -p ${WORKSPACE}/xunit-reports
    cp ${RACKHD_DIR}/test/*.xml ${WORKSPACE}/xunit-reports
}


####################################
#
# Start to run FIT tests
#
##################################
runFIT() {
    set +e
    netstat -ntlp
    pushd ${RACKHD_DIR}/test
    echo "########### Run FIT Smoke Test #############"
    python run_tests.py ${TEST_GROUP} -stack docker_local_run -v 4 -xunit
    if [ $? -ne 0 ]; then
        echo "Test FIT failed to test ${TEST_GROUP}"
        collectTestReport
        exit 1
    fi
    collectTestReport
    popd
    set -e
}


##############################################
#
# Set up test environment and run test
#
#############################################
runTests(){
    setupTestsConfig
    setupVirtualEnv
    runFIT " --sm-amqp-use-user guest"
}

##############################################
#
# Back up exist dir or file
#
#############################################
backupFile(){
    if [ -d $1 ];then
        mv $1 $1-bk
    fi
    if [ -f $1 ];then
        mv $1 $1.bk
    fi
}

#######################################
#
# Main
#
#####################################
main(){
    while [ "$1" != "" ]; do
        case $1 in
            -w | --WORKSPACE )              shift
                                            WORKSPACE=$1
                                            ;;
            -r | --RACKHD_DIR )             shift
                                            RACKHD_DIR=$1
                                            ;;
            -p | --SUDO_PASSWORD )          shift
                                            SUDO_PASSWORD=$1
                                            ;;
            -g | --TEST_GROUPS )            shift
                                            TEST_GROUP="$1"
                                            ;;
            * )                             echo "[Error]$0: Unkown Argument: $1"
                                            Usage
                                            exit 1
        esac
        shift
    done
    if [ ! -n "$WORKSPACE" ]; then
        echo "The argument -w|--WORKSPACE is required"
        exit 1
    else
        if [ ! -d "${WORKSPACE}" ]; then
            mkdir -p ${WORKSPACE}
        fi
    fi

    if [ ! -n "$SUDO_PASSWORD" ]; then
        echo "The argument -p|--SUDO_PASSWORD is required"
        exit 1
    fi

    if [ ! -n "$RACKHD_DIR" ]; then
        pushd $WORKSPACE
        backupFile RackHD
        git clone https://github.com/RackHD/RackHD
        RACKHD_DIR=$WORKSPACE/RackHD
        popd

    fi
    if [ ! -n "$TEST_GROUP" ]; then
        TEST_GROUP="-group smoke"
    fi

    runTests
}

main "$@"
