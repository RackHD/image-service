// Copyright 2015, EMC, Inc.
/* jshint node:true */

'use strict';

describe('northbound-api', function () {
    var Promise;
    var Errors;

    var fs = helper.injector.get('fs');
    var path = helper.injector.get('path');
    var _ = helper.injector.get('_');
    var configuration;

    var cwd = process.cwd();

    var fakeStaticDir = "./spec/fake-static";
    var fakeIsoDir = "./spec/fake-static/iso";
    var fakeMKDir = "./spec/fake-static/common";
    var fakeInventoryFile = "./spec/data/inventory.json";

    var fakeIsoDirAbs = path.join(cwd, "./spec/fake-static/iso");
    var fakeMKDirAbs = path.join(cwd, "./spec/fake-static/common");
    var fakeIsoFile = path.join(cwd, "./spec/data/fake.iso");
    var fakeMicrokernelFile = path.join(cwd, "./spec/data/fake.microkernel");

    var endpoints = [
        {
            "address": "0.0.0.0",
            "port": 7071,
            "routers": "northbound"
        },
        {
            "address": "0.0.0.0",
            "port": 9091,
            "routers": "southbound"
        }
    ];

    var testIso = {
        name: 'fake.iso',
        size: '360.45 KB',
        uploaded: '2016-11-17T13:59:59.425Z'
    };

    var testMicrokernel = {
        name: 'test.microkernel',
        size: '17 Byte',
        uploaded: '2016-11-17T13:59:59.425Z'
    };

    var testImage = {
        name: 'ubuntu',
        version: 'trusty'
    };

    var urlNorth = 'http://localhost:7071';

    function setupConfig() {
        configuration = helper.injector.get('Services.Configuration');
        configuration.set("httpFileServiceRootDir", fakeStaticDir)
            .set("isoDir", fakeIsoDir)
            .set("microkernelDir", fakeMKDir)
            .set("inventoryFile", fakeInventoryFile);
    }

    function restoreConfig() {
        configuration.set("httpFileServiceRootDir", './static')
            .set("isoDir", './static/iso')
            .set("microkernelDir", './static/common')
            .set("inventoryFile", './inventory.json');
    }

    function setupInventoryFile() {
        fs.writeFileSync(path.join(cwd, fakeInventoryFile), '{"images": []}');
    }

    function getMicrokernelFiles(){
        return getFiles(fakeMKDirAbs);
    }

    function getIsoFiles() {
        return getFiles(fakeIsoDirAbs);
    }

    function getFiles(link){
        return fs.readdirSync(link);
    }

    function setupFakeStatic(){
        fs.mkdirSync(fakeStaticDir);
        fs.mkdirSync(fakeIsoDir);
        fs.mkdirSync(fakeMKDir);
    }

    function prepareDir() {
        setupInventoryFile();
        setupFakeStatic();
    }

    function removeFakeStatic(done) {
        if (fs.statSync(fakeStaticDir)){
            var rimraf = require('rimraf');
            rimraf(fakeStaticDir, function(err){
                if (err) {
                    done(err);
                }
                else {
                    done();
                }
            });
        }
    }

    function verifyMicrokernelExistance(name) {
        var fileList = getMicrokernelFiles();
        return _.contains(fileList, name);
    }

    function verifyIsoExistance(name) {
        var fileList = getIsoFiles();
        return _.contains(fileList, name);
    }

    function verifyMountContent(osName, osVersion) {
        var fakeMountDir = path.join(fakeStaticDir,
            osName + '/' + osVersion + '/');

        var mountDirContent = fs.readdirSync(fakeMountDir);
        if(_.isEqual(mountDirContent, [ 'test_fil', 'test_fol' ])) {
            return true;
        } else {
            return false;
        }
    }

    before('setup config', function () {
        setupConfig();
        prepareDir();
    });

    after('restore config', function (done) {
        restoreConfig();
        setupInventoryFile();
        removeFakeStatic(done);
    });

    before('start HTTP server', function () {
        this.timeout(5000);

        return helper.startServer(endpoints).then(function () {
            Promise = helper.injector.get('Promise');
            Errors = helper.injector.get('Errors');
        });
    });

    after('stop HTTP server', function () {
        return helper.stopServer();
    });

    describe("Test /iso", function () {

        it("should return empty iso files", function () {

            return helper.request(urlNorth).get('/iso')
                .set('Content-Type', 'application/json')
                .expect(200)
                .expect(function (res) {
                    expect(res.body).to.be.an("Array").with.length(0);
                });
        });

        it("should put one iso file with query in url", function () {

            return helper.request(urlNorth).put('/iso?name=' + testIso.name)
                .send(fs.readFileSync(fakeIsoFile, 'ascii'))
                .expect(204);
        });

        it("should return one iso files", function () {
            return helper.request(urlNorth).get('/iso')
                .set('Content-Type', 'application/json')
                .expect(200)
                .expect(function (res) {
                    expect(res.body).to.be.an("Array").with.length(1);
                    res.body[0].name.should.equal(testIso.name);
                    //res.body[0].size.should.equal(testIso.size);
                    expect(verifyIsoExistance(testIso.name)).to.equal(true);
                });
        });

        it("should delete one iso", function () {
            return helper.request(urlNorth).delete('/iso?name=' + testIso.name)
                .set('Content-Type', 'application/json')
                .expect(200)
                .expect(function (res) {
                    expect(res.body).to.be.an("object");
                    res.body.name.should.equal(testIso.name);
                    //res.body.size.should.equal(testIso.size);
                    expect(verifyIsoExistance(testIso.name)).to.equal(false);
                });
        });
    });

    describe("Test /microkernel", function () {

        it("should return empty microkernel files", function () {

            return helper.request(urlNorth).get('/microkernel')
                .set('Content-Type', 'application/json')
                .expect(200)
                .expect(function (res) {
                    expect(res.body).to.be.an("Array").with.length(0);
                });
        });

        it("should put one microkernel file with query in url", function () {

            return helper.request(urlNorth).put('/microkernel?name=' + testMicrokernel.name)
                .send(fs.readFileSync(fakeMicrokernelFile, 'ascii'))
                .expect(204);
        });

        it("should return one microkernel files", function () {
            return helper.request(urlNorth).get('/microkernel')
                .set('Content-Type', 'application/json')
                .expect(200)
                .expect(function (res) {
                    expect(res.body).to.be.an("Array").with.length(1);
                    res.body[0].name.should.equal(testMicrokernel.name);
                    //res.body[0].size.should.equal(testMicrokernel.size);
                    expect(verifyMicrokernelExistance(testMicrokernel.name)).to.equal(true);
                });
        });

        it("should delete one microkernel", function () {
            return helper.request(urlNorth).delete('/microkernel?name=' + testMicrokernel.name)
                .set('Content-Type', 'application/json')
                .expect(200)
                .expect(function (res) {
                    expect(res.body).to.be.an("object");
                    res.body.name.should.equal(testMicrokernel.name);
                    //res.body.size.should.equal(testMicrokernel.size);
                    expect(verifyMicrokernelExistance(testMicrokernel.name)).to.equal(false);
                });
        });
    });

    describe("Test /Images", function () {

        it("should return empty Images files", function () {

            return helper.request(urlNorth).get('/images')
                .set('Content-Type', 'application/json')
                .expect(200)
                .expect(function (res) {
                    expect(res.body).to.be.an("Array").with.length(0);
                });
        });

        it("should put one Images file using isolocal", function () {

            this.timeout(5000);

            return helper.request(urlNorth).put('/images?name=' + testImage.name +
                '&version=' + testImage.version + '&isolocal=' + fakeIsoFile)
                .expect(200)
                .set('Content-Type', 'application/json')
                .expect(function (res) {
                    var image = res.body;
                    expect(image.name).to.equal(testImage.name);
                    expect(image.version).to.equal(testImage.version);
                    expect(image.status).to.equal('OK');
                    expect(image.iso).to.equal(testIso.name);

                    expect(verifyMountContent(testImage.name, testImage.version)).to.equal(true);
                });
        });

        it("should return one Images files", function () {
            return helper.request(urlNorth).get('/images')
                .set('Content-Type', 'application/json')
                .expect(200)
                .expect(function (res) {
                    expect(res.body).to.be.an("Array").with.length(1);
                    expect(res.body[0].name).to.equal(testImage.name);
                    expect(res.body[0].version).to.equal(testImage.version);

                });
        });

        it("should delete one images", function () {
            return helper.request(urlNorth).delete('/images?name=' + testImage.name)
                .set('Content-Type', 'application/json')
                .expect(200)
                .expect(function (res) {
                    expect(res.body).to.be.an("Array");
                    expect(res.body[0].name).to.equal(testImage.name);
                    expect(res.body[0].version).to.equal(testImage.version);
                });
        });
    });

});

