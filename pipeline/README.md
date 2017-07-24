# pipeline

Directory 'pipeline' contains all the CI/CD pipelines of image service.
Currently, there are 2 pipelines: 
- [BuildBaseImage](http://147.178.202.18/job/image-service/job/BuildBaseImage/)
- [PR Gate](http://147.178.202.18/job/image-service/job/PR_Gate/)

Copyright 2017, DELLEMC, Inc.

## Build Base Image

*The entry point of BuildBaseImage: pipeline/BuildBaseImage/Jenkinsfile*

The pipeline is responsible for building a base docker image which contains all the prerequisites for image-service.
Pipelines which run test with docker, such as PR Gate, will build docker from the base image. 
That will save the test time and increase the reliability in case unstable network.


## PR Gate

*The entry point of PR_Gate: pipeline/PRGate.groovy*

The pipeline is responsible for testing each pull request of image-service.
Each pull request of image-service will trigger the building of the pipeline.
It includes 2 main stages: 
1. Unit Test: run Unit Test.
2. Function Test: run Function Test against the pull request.

