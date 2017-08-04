def deploy(String repo_dir, String base_image_job_name="", String base_image_name=""){
    withCredentials([
        usernamePassword(credentialsId: 'ff7ab8d2-e678-41ef-a46b-dd0e780030e1',
                         passwordVariable: 'SUDO_PASSWORD',
                         usernameVariable: 'SUDO_USER')])
    {
        if(base_image_job_name != ""){
            step ([$class: 'CopyArtifact',
                  projectName: base_image_job_name,
                  target: "$WORKSPACE"])

            sh """#!/bin/bash -ex
            # Load base image for test
            echo $SUDO_PASSWORD |sudo -S docker load -i $WORKSPACE/$base_image_name
            pushd $repo_dir
            cp pipeline/Dockerfile .
            popd
            """
        }

        sh """#!/bin/bash -ex
        # Deploy image-service docker container which is from base image
        pushd $repo_dir
        ./deploy.sh deploy -w $WORKSPACE -p $SUDO_PASSWORD -d $repo_dir
        popd
        """
    }
}

def test(){
    checkout(
    [$class: 'GitSCM', branches: [[name: 'master']],
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "$WORKSPACE/RackHD"]],
    userRemoteConfigs: [[url: 'https://github.com/RackHD/RackHD']]])

    withCredentials([
        string(credentialsId: 'eos_token', variable: 'eos_token'),
        usernamePassword(credentialsId: 'ff7ab8d2-e678-41ef-a46b-dd0e780030e1',
                         passwordVariable: 'PASSWORD',
                         usernameVariable: 'USER')])
    {
        try{
            sh """#!/bin/bash -ex
            curl -k -H "Authorization: token $eos_token" https://raw.eos2git.cec.lab.emc.com/OnRack/dellemc-test/master/config-sh/imageservice_config.json -o RackHD/test/config/imageservice_config.json
            pushd $WORKSPACE/RackHD/test
            ./runFIT.sh -g "-test tests/imageserver -group imageservice -extra imageservice_config.json" -w $WORKSPACE -p $PASSWORD -v 9
            popd
            """
        } finally{
            junit 'xunit-reports/*.xml'
            archiveArtifacts 'xunit-reports/*.xml, build-logs/*.log'
        }
    }
}

def cleanUp(String repo_dir){
    withCredentials([
        usernamePassword(credentialsId: 'ff7ab8d2-e678-41ef-a46b-dd0e780030e1',
                         passwordVariable: 'SUDO_PASSWORD',
                         usernameVariable: 'SUDO_USER')])
    {
        sh """#!/bin/bash
        set +e
        pushd $repo_dir
        # Clean up exsiting image-service docker containers and images
        ./deploy.sh cleanUp -w $WORKSPACE -p $SUDO_PASSWORD -d $repo_dir
        popd
        """
    }
}


def runTest(String library_dir, String base_image_job_name="", String base_image_name=""){
    if (! fileExists("$library_dir/jobs/ShareMethod.groovy")){
        error("$library_dir/jobs/ShareMethod.groovy doesn't exist")
    }
    def shareMethod = load("$library_dir/jobs/ShareMethod.groovy")
    String label_name="smoke_test"
    lock(label:label_name,quantity:1){
        node_name = shareMethod.occupyAvailableLockedResource(label_name, [])
        node(node_name){
            deleteDir()
            dir("image-service"){
                checkout scm
            }
            def repo_dir="$WORKSPACE/image-service"
            try{
                cleanUp(repo_dir)
                deploy(repo_dir, base_image_job_name, base_image_name)
                test()
            } finally{
                cleanUp(repo_dir)
            }
        }
    }
}

return this
