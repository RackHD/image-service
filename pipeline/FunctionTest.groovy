def deploy(String repo_dir){
    withCredentials([
        usernamePassword(credentialsId: 'ff7ab8d2-e678-41ef-a46b-dd0e780030e1',
                         passwordVariable: 'SUDO_PASSWORD',
                         usernameVariable: 'SUDO_USER')])
    {
        step ([$class: 'CopyArtifact',
              projectName: 'image-service/BuildBaseImage',
              target: "$WORKSPACE"])

        sh """#!/bin/bash -ex
        pushd $repo_dir
        # Clean up exsiting image-service docker containers and images
        ./deploy.sh cleanUp -w $WORKSPACE -p $SUDO_PASSWORD -d $repo_dir

        # Load base image for test
        echo $SUDO_PASSWORD |sudo -S docker load -i $WORKSPACE/image_service_pipeline_docker.tar
        cp pipeline/Dockerfile .

        # Deploy image-service docker container which is from base image
        ./deploy.sh deploy -w $WORKSPACE -p $SUDO_PASSWORD -d $repo_dir
        popd
        """
    }
}

def test(String repo_dir){
    checkout(
    [$class: 'GitSCM', branches: [[name: 'master']],
    extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: "$WORKSPACE/RackHD"]],
    userRemoteConfigs: [[url: 'https://github.com/RackHD/RackHD']]])

    withCredentials([
        string(credentialsId: 'eos_token', variable: 'eos_token'),
        usernamePassword(credentialsId: 'ff7ab8d2-e678-41ef-a46b-dd0e780030e1',
                         passwordVariable: 'SUDO_PASSWORD',
                         usernameVariable: 'SUDO_USER')])
    {
        try{
            sh """#!/bin/bash -ex
            curl -k -H "Authorization: token $eos_token" https://raw.eos2git.cec.lab.emc.com/OnRack/dellemc-test/master/config-sh/imageservice_config.json -o RackHD/test/config/imageservice_config.json
            pushd $repo_dir
            ./runFIT.sh -g "-test tests/imageserver -group imageservice -extra imageservice_config.json" -w $WORKSPACE -p $SUDO_PASSWORD -r $WORKSPACE/RackHD
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
        ./deploy.sh cleanUp -w $WORKSPACE -p $SUDO_PASSWORD -d $repo_dir
        popd
        """
    }
}


def runTest(String library_dir){
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
                deploy(repo_dir)
                test(repo_dir)
            } finally{
                cleanUp(repo_dir)
            }
        }
    }
}

return this
