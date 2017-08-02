# image-service

## Introduction

image-service is a tool that help RackHD users to manage static file resources like os images and microkernel images. It is very convenient for users to create their OS image server when installing various OSes through RackHD comparing to original method.

With image-service, users can

* **Create http server** that server stores operation system images used for [RackHD](https://github.com/rackhd) OS installation. OS images are mounted from iso files that can be loaded from different sources.
* **Mount uploaded iso files** and expose it from http server.
* **Manage iso files**. Users can list in-store iso files, upload a new iso file, delete a in-store iso file.
* **Manage microkernel files**. Users can get/upload/delete microkernel files used in RackHD node discovery, including vmlinuz, initrd, basefs and overlay fs image files.
* **Restore settingsi** after service restart. image-service stores user image settings on the file-based persistant storage. Every time image-service gets started, it loads the user image settings from the storage and get everything setup. 

Two http servers are created by default:

* The northbound: Handles user requests like managing (list/create/delete) an OS image, or managing (list/create/delete) an iso file.
* The southbound: The http file server.

## Deployment

It's recommended to deploy the image-service on a standalone host to offload the host that runs RackHD.

The host running image-service is better to have two NICs, one for northbond API and one for southbond API. The NIC for southbound API should be accessible by RackHD nodes#
One example is to connect the northbond NIC to RackHD control network.

 ![Deploy Example](image-service-deployment.bmp)

## How to start image service

Install image-service is quite straight forward.

```
git clone https://github.com/RackHD/image-service.git
cd image-service
npm install
sudo node index.js
```

By default, the northbound API listens at 0.0.0.0:7070, and the southbound listens at 0.0.0.0:9090. Those IP addresses and ports are user configurable.

You can also run it as a Linux service. Install the service:

```
sudo ./install
```

And then run the service:

```
sudo service image-service start
```

The log files are located at:

```
/var/log/image-service/image-service.log
```

## Use it with RackHD (Take Ubuntu installation with image service as a example)

Assume users already have a RackHD instance running and they want to install ubuntu to one of their nodes. 

First, they have to setup a unbutu image server. The setups are:

1. Locate where the unbutu iso file is. They can choose to download it by themselves or just ask image-service to download it instead. 
2. Setup the ubuntu image server by send a PUT request to image-service northbound API, something look like:

        curl -X PUT "http://10.62.59.150:7070/images?name=ubuntu&version=14.04&isoweb=http://10.62.59.150:9090/iso/photon-1.0.iso"

3. Make sure the RackHD config file has the following configurations so that it will go to an external static file server for os images.

    ```
    "fileServerAddress": "172.31.128.4", # this is the northbond IP of image-service, make sure it's accessible by managed nodes. 
    "fileServerPort": 9090,
    "fileServerPath": "/",
    ```

    RackHD configure files can be find at:

        /opt/monorail/config.json
    or
        /opt/onrack/etc/monorail.json

4. Issue OS installation workflow with repo key in payload set to "http://image-service-ip-addr:port/ubuntu/14.04". 

    The API look like:

        http://{{host}}/api/2.0/nodes/:identifier/workflows?name=Graph.InstallUbuntu

    And the payload look like:

    ```
    {
        "options": {
            "defaults": {
                "version": "trusty",
                "baseUrl": "install/netboot/ubuntu-installer/amd64",
                "kargs": {
                    "live-installer/net-image": "http://image-service-ip-addr:port/ubuntu/14.04/ubuntu/install/filesystem.squashfs"
                },
                "repo": "http://image-service-ip-addr:port/ubuntu/14.04"
            }
        }
    }
    ```

## Image service API Details

### Northbound

* Image management

    1. GET http://0.0.0.0:7070/images: Get/list all OS images. No parameter is needed.

        ```
        curl http://0.0.0.0:7070/images | python -m json.tool
        [
            {
                "id": "6807e9b2-a763-4b74-bfe9-4b20fe964400",
                "iso": "client.iso",
                "name": "photon",
                "status": "OK",
                "version": "6.0"
            }
        ]
        ```

    2. PUT http://0.0.0.0:7070/images: Add OS images. Three parameters are needed.
        * name: in query or body, the OS name. Should be one of [ubuntu, rhel, photon, centos]. The list will expand as we move on. 
        * version: in query of body, the OS version. User can use any string they like. Examples will include, 14.04, 14.04-x64, 14.04-EMC-Ted-test.
        * isoweb, isostore, isolocal or isoclient: the source of the iso file used to build the OS image. At least one of those four should be specified. If more than one are specified, image-service uses isostore over isolocal over isoweb over isoclient. 
            * isoweb: use iso file from the web, can be http or ftp, like _http://example.com/example.iso_. **Https** is not verified yet.
            * isolocal: use iso file from the server which image-service is running.
            * isoclient: use iso file uploaded from user client where the APIs are called. Iso files are uploaded with HTTP PUT method.
            * isostore: use in-store iso file that has been uploaded before from above three sources. This is useful when you are adding a OS image that had been removed earlier.

            Using **isoclient**

            ```
            curl -X PUT "http://10.62.59.150:7070/images?name=photon&version=1.0&isoclient=client.iso" --upload-file path-to-file/test.iso
            Uploaded 100 %
            Upload finished!
            ```

            Using **isoweb**. image status will be set as 'downloading iso' and iso download will be carried out at the background. You can check the status afterwards using get/list image API. 

            ```
            curl -X PUT "http://10.62.59.150:7070/images?name=photon&version=1.0&isoweb=http://10.62.59.150:9090/iso/photon-1.0.iso"
            {
                "id": "39647624-e640-41d0-901b-afc58af98725",
                "iso": "photon-1.0.iso",
                "name": "photon",
                "version": "1.0",
                "status": "downloading iso"
            }
            ```

            Using **isolocal**.

            ```
            curl -X PUT "http://10.62.59.150:7070/images?name=centos&version=7.0&isolocal=/home/onrack/github/image-service/static/files/iso/centos-7.0.iso"
            {
                "id": "9fce7e8f-c7ef-49db-a47f-1924675d5e29",
                "iso": "/home/onrack/github/image-service/static/files/iso/centos-7.0.iso",
                "name": "centos",
                "version": "7.0",
                "status": "preparing"
            }
            ```

            Using **isostore**.

            ```
            curl -X PUT "http://10.62.59.150:7070/images?name=centos&version=7.0&isostore=centos-7.0.iso"
            {
                "id": "b6b3e3be-c799-4af4-86c8-09a99d3aa7c7",
                "iso": "centos-7.0.iso",
                "name": "centos",
                "version": "7.0",
                "status": "preparing"
            }
            ```

    3. DELETE http://0.0.0.0:7070/images: delete an OS images. Two parameters are needed.
        * name: in query or body, the OS name.
        * version: in query of body, the OS version.

        ```
        curl -X DELETE -H "Content-Type: application/json" -d '' "http://10.62.59.150:7070/images?name=centos&version=7.0"
        {
            "id": "b6b3e3be-c799-4af4-86c8-09a99d3aa7c7",
            "iso": "centos-7.0.iso",
            "name": "centos",
            "version": "7.0",
            "status": "preparing"
        }
        ```

* Iso file management

    1. Get/list install iso files.

        ```
        curl -X GET "http://10.62.59.150:7070/iso"
        [
            {
                "name": "centos-7.0.iso",
                "size": "4.15 GB",
                "upload": "2016-10-18T18:02:50.769Z"
            },
            {
                "name": "test.iso",
                "size": "1.00 KB",
                "upload": "2016-10-21T10:02:01.204Z"
            }
        ]
        ```

    2. Upload an iso file. One parameter is needed.
        * name: in query or in body, the name of the iso that will be shown in the store.

        ```
        curl -X PUT "http://10.62.59.150:7070/iso?name=test.iso" --upload-file static/files/iso/centos-7.0.iso
        Uploaded 10 %
        Uploaded 20 %
        Uploaded 30 %
        Uploaded 40 %
        Uploaded 50 %
        Uploaded 60 %
        Uploaded 70 %
        Uploaded 80 %
        Uploaded 90 %
        Uploaded 100 %
        Upload finished!
        ```

    3. Delete a iso file that is in the store. One parameter is needed.
        * name: in query or in body, the name of the iso will be deleted.

        ```
        curl -X DELETE "http://10.62.59.150:7070/iso?name=test.iso"
        {
            "name": "centos-7.0.iso",
            "size": "4.15 GB",
            "upload": "2016-10-18T18:02:50.769Z"
        }
        ```

* Microkernel file management
The Microkernel file management API works similar to iso file management API.

    1. Get/list install microkernel files.

        ```
        curl -X GET "http://10.62.59.150:7070/microkernel"
        [
          {
            "name": "base.trusty.3.16.0-25-generic.squashfs.img",
            "size": "61.11 MB",
            "uploaded": "2016-11-10T16:44:10.311Z"
          },
          {
            "name": "discovery.overlay.cpio.gz",
            "size": "8.59 MB",
            "uploaded": "2016-11-10T16:44:10.351Z"
          },
          {
            "name": "initrd.img-3.16.0-25-generic",
            "size": "23.24 MB",
            "uploaded": "2016-11-10T16:44:10.607Z"
          },
          {
            "name": "vmlinuz-3.16.0-25-generic",
            "size": "6.34 MB",
            "uploaded": "2016-11-10T16:44:11.939Z"
          }
        ]
        ```

    2. Upload a microkernel file. One parameter is needed.
        * name: in query or in body, the name of the microkernel that will be shown in the store.

        ```
        curl -X PUT "http://10.62.59.150:7070/microkernel?name=vmlinuz-3.16.0-25-generic" --upload-file vmlinuz-3.16.0-25-generic
        Uploaded 10 %
        Uploaded 20 %
        Uploaded 30 %
        Uploaded 40 %
        Uploaded 50 %
        Uploaded 60 %
        Uploaded 70 %
        Uploaded 80 %
        Uploaded 90 %
        Uploaded 100 %
        Upload finished!
        ```

    3. Delete a microkernel file that is in the store. One parameter is needed.
        * name: in query or in body, the name of the microkernel will be deleted.

        ```
        curl -X DELETE "http://10.62.59.150:7070/microkernel?name=vmlinuz-3.16.0-25-generic"
        {
            "name": "vmlinuz-3.16.0-25-generic",
            "size": "6.34 MB",
            "uploaded": "2016-11-10T16:44:11.939Z"
        }
        ```

### Southbound

The southbound is all about static file server. It's by default listen at 0.0.0.0:9090. It also expose a GUI so that if you navigate to http://0.0.0.0:9090/ using your favorate web browser, you will get files and directories listed. 

## Image service Configuration

There are not much to be configured for image-service. The Configuration is set on image-service/config.json file. Following is an example:

```
{
  "httpEndpoints": [
    {
      "address": "0.0.0.0",
      "port": 7070,
      "routers": "northbound"
    },
    {
      "address": "0.0.0.0",
      "port": 9090,
      "routers": "southbound"
    }
  ],
  "httpFileServiceRootDir": "./static",
  "httpFileServiceApiRoot": "/",
  "isoDir": "./static/iso",
  "microkernelDir": "./static/common",
  "inventoryFile": "./inventory.json",
  "httpTimeout": "86400000"
}

```

The Configurations explained as below:

* httpEndpoints: the http endpoint settings. Each endpoint represents a http service, either northbound or southbound. At lease one endpoint for northbound service and one endpoint for southbound service is a must have. More endpoints are also supported as per user configuration needs. Each endpoint has three parameters:
    * address: the IP address that the service is listen on. Specifically, 0.0.0.0 means listening on all network interfaceses, 127.0.0.1 means only listen to local loop interface. 
    * port: the port the service is listen on.
    * routers: should be one of northbound and southbound.

    Care should be taken when configuring the endpoints to makesure the IP address and port is not conflicting with other web services on the same server. 

* httpFileServiceRootDir: the root dir that the sourcebound service serves. It should be a relative path to the image-service root directory. Furture work can be added to support the absolute path. 
* httpFileServiceApiRoot: the API root for southbound service.
* isoDir: the dir where user-uploaded iso files are stored, also a relative path.
* microkernelDir: the dir where user-uploaded microkernel files are stored, also a relative path.
* inventoryFile: the file where user image settings are stored.
* httpTimeout: The timeout in microsecond for every http request. Default to 24 hours. Take this into account if your are trying to upload a large file to image-service.
* minLogLevel: The minimal log serverity level, defaults to 0, with valid value range from 0 to 5. Less log is print to console if the number is larger. 0 prints logs of all serverity to screen and 4 only prints critical errors. 5 and larger prints no log to screen.


## Web UI

There is a simple web UI to ease users' oprations. Run the command to generate the webpage:

```
sudo npm run build
```

After starting image service, users can open it via http://<image-server-ip>:7070. They can manage mounted files, iso files and microkernel files through this UI.

## Development notes

### Run jshint and unit test coverage report

```
./HWIMO-TEST
```

Unit test coverage report can be found at ./coverage

### One Approach To Run Image Service API Related Case in FIT From Scratch
```
WORKSPACE=`pwd`
# Get latest image-service code and FIT code from git hub
git clone https://github.com/RackHD/image-service.git
git clone https://github.com/RackHD/RackHD.git

pushd image-service
# Cleanup environment for test
./deploy.sh cleanUp -w $WORKSPACE -p $SUDO_PASSWORD -d $WORKSPACE/image-service

# Deploy image service docker container
./deploy.sh deploy -w $WORKSPACE -p $SUDO_PASSWORD -d $WORKSPACE/image-service
popd

# Run smoke test with $WORKSPACE/image-service
pushd RackHD/test
./runFIT.sh -g "-test tests/imageserver -group imageservice -extra imageservice_config.json" -w $WORKSPACE -p $SUDO_PASSWORD
popd
```


## Contributions are welcome

This feature is done  by Ted Chen(Huaqi, Chen), and the initial commit is forked from his repo: https://github.com/cgx027/on-static
_Copyright 2015-2016, EMC, Inc._

