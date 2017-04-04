var AWS = require('aws-sdk');
var unzip = require('unzip');
var stream = require('stream');

exports.handler = function(event, context) {
    var codepipeline = new AWS.CodePipeline({apiVersion: '2015-07-09'});
    var s3 = new AWS.S3({apiVersion: '2006-03-01', signatureVersion: 'v4'});
    var cloudformation = new AWS.CloudFormation({apiVersion: '2010-05-15', region: 'eu-west-2'});

    // Retrieve the Job ID from the Lambda action
    var jobId = event["CodePipeline.job"].id;

    var userParams = JSON.parse(event["CodePipeline.job"].data.actionConfiguration.configuration.UserParameters);

    var cfParamsFilename = userParams.AppName + '/' + userParams.Env + '.json'
    var cfTemplatesFilename = 'hosting/stack-template.yaml'
    var buildTagFilename = 'BUILD_TAG.txt'

    console.log('CodePipeline Job ID:', jobId);
    console.log('Going to deploy:', userParams);
    console.log('Expecting to find params file at:', paramsFilename);

    // Notify CodePipline of successful job, and exit with success
    var exitSuccess = function(message) {
        var params = { jobId: jobId }
        codepipeline.putJobSuccessResult(params, function(err, data) {
            if (err) {
                context.fail(err);
            } else {
                context.succeed(message);
            }
        });
    };

    // Notify CodePipeline of failed job, and exit with failure
    var exitFailure = function(message) {
        var params = {
            jobId: jobId,
            failureDetails: {
                message: message,
                type: 'JobFailed'
            }
        }
        codepipeline.putJobFailureResult(params, function(err, data) {
            if (err) {
                context.fail(err);
            } else {
                context.fail(message);
            }
        });
    };

    var readFile = function(stream, cb) {
        var chunks = [];
        stream.on('data', function(chunk) {
            chunks.push(chunk.toString());
        });
        stream.on('end', function() {
            cb(chunks.join(''));
        });
    };

    var artifacts = event["CodePipeline.job"].data.inputArtifacts;
    var promises = [];

    artifacts.forEach(function(artifact) {
        var artifactName = artifact.name

        var s3Params = {
            Bucket: artifact.location.s3Location.bucketName,
            Key: artifact.location.s3Location.objectKey
        }

        var mypromise = new Promise(function(fulfill, reject) {
            s3.getObject(s3Params).createReadStream()
            .pipe(unzip.Parse())
            .on('entry', function (entry) {
                var fileName = entry.path;

                var returnFile = function() {
                    readFile(entry, function(fileContents) {
                        fulfill({name: fileName, contents: fileContents});
                    });
                };

                if (artifactName == 'CfTemplates' && fileName == cfTemplatesFilename) {
                    returnFile();
                } else if (artifactName == 'CfParams' && fileName == cfParamsFilename) {
                    returnFile();
                } else if (artifactName == 'DeployTag' && fileName == buildTagFilename) {
                    returnFile();
                } else {
                    entry.autodrain();
                }
            });
        });

        promises.push(mypromise);
    });

    Promise.all(promises).then(function(values) {
        var stackParams = values.find((f) => { return f.name === cfParamsFilename; }).contents;
        var cloudTemplate = values.find((f) => { return f.name === cfTemplatesFilename; }).contents;
        var buildTag = values.find((f) => { return f.name === buildTagFilename; }).contents;

        stackParams = JSON.parse(stackParams);

        var dockerImage;
        stackParams.forEach((value, index) => {
            if (value.ParameterKey == 'DockerImage') {
                stackParams[index].ParameterValue =
                  stackParams[index].ParameterValue.replace('<DEPLOY_TAG>', buildTag);
                  dockerImage = stackParams[index].ParameterValue;
            }
        });

        var cloudFormationParams = {
            StackName: userParams.AppName + '-' + userParams.Env,
            TemplateBody: cloudTemplate,
            UsePreviousTemplate: false,
            Parameters: stackParams,
            Capabilities: [ 'CAPABILITY_IAM' ]
        };

        console.log('Using build tag:', buildTag);
        console.log('Docker image:', dockerImage);

        var cloudFormationPromise = new Promise(function(fulfill, reject) {
            cloudformation.updateStack(cloudFormationParams, function(err, data) {
                if (err) {
                    console.log(err, err.stack);
                    reject(err);
                } else {
                    console.log(data);
                    fulfill(data);
                }
            });
        });

        cloudFormationPromise.then(function(result) {
            exitSuccess('Stack Updated');
        }, function(err) {
            console.log('Failed to update CloudFormation stack');
            console.log(err);
            exitFailure('Failed to update CloudFormation stack');
        });

    }).catch(function(err) {
        console.error('Unable to extract files from zipped input artifacts!');
        console.error(err);
        exitFailure('Unable to extract files from zipped input artifacts!');
    });
};
