node{
    timestamps{
        deleteDir()

        checkout(
        [$class: 'GitSCM', branches: [[name: 'master']],
        extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'on-build-config']],
        userRemoteConfigs: [[url: 'https://github.com/RackHD/on-build-config']]])
        String library_dir="$WORKSPACE/on-build-config"

        shareMethod = load("$library_dir/jobs/ShareMethod.groovy")

        try{
            String repo_dir = ""
            stage("Check Out PR"){
                dir("image-service"){
                    checkout scm
                }
                repo_dir = "$WORKSPACE/image-service"
            }
            
            stage("Unit Test"){
                unit_test = load("$repo_dir/pipeline/UnitTest.groovy")
                unit_test.runTest(library_dir)
            }
            
            stage("FunctionTest"){
                function_test = load("$repo_dir/pipeline/FunctionTest.groovy")
                function_test.runTest(library_dir, "image-service/BuildBaseImage", "image_service_pipeline_docker.tar")
            }
            currentBuild.result="SUCCESS"
            
        } finally{
            stage("Write Back"){
                String manifest_path = "$WORKSPACE/manifest.json"
                shareMethod.generateManifestFromPR(manifest_path)
                shareMethod.writeBackToGitHub(library_dir, manifest_path)
            }
            shareMethod.sendResult(true, true)
        }
    }
}
