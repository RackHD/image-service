def runTest(String library_dir){
    def shareMethod = load("$library_dir/jobs/ShareMethod.groovy")
    String label_name="unittest"
    lock(label:label_name,quantity:1){
        node_name = shareMethod.occupyAvailableLockedResource(label_name, [])
        node(node_name){
            deleteDir()
            checkout scm
            withCredentials([
                usernamePassword(credentialsId: 'ff7ab8d2-e678-41ef-a46b-dd0e780030e1',
                                 passwordVariable: 'SUDO_PASSWORD',
                                 usernameVariable: 'SUDO_USER')
                ]){
                try{
                    sh """#!/bin/bash -ex
                    pushd $WORKSPACE
                    # Because unit test of image service need to do mount, sudo is required.
                    echo $SUDO_PASSWORD | sudo -S ./HWIMO-TEST
                    popd
                    """
                } finally{
                    sh """#!/bin/bash
                    set +e
                    pushd $WORKSPACE
                    echo $SUDO_PASSWORD | sudo -S chown -R $USER:$USER node_modules coverage static *.xml
                    popd
                    """
                    junit "*.xml"
                    archiveArtifacts "*.xml"
                }
            }
        }
    }
}
return this
