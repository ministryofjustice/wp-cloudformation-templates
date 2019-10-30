#!/bin/bash
echo "What is the app name?"
read APP_NAME

echo "What is the repo name?"
read REPO_NAME

echo "Which branch should I deploy from? (leave blank for master)"
read REPO_BRANCH
if [ -z "$REPO_BRANCH" ]
then
	REPO_BRANCH="master"
fi

echo "What is your GitHub access token?"
echo "If you don't have one, go to https://github.com/settings/tokens"
read GITHUB_TOKEN

echo "What is the username for composer.wp.dsd.io?"
read COMPOSER_USER

echo "What is the password for composer.wp.dsd.io?"
read COMPOSER_PASSWORD

echo "Just to confirm:"
echo
echo "App name: $APP_NAME"
echo "Repo name: $REPO_NAME"
echo "Repo branch: $REPO_BRANCH"
echo "GitHub token: $GITHUB_TOKEN"
echo "Composer username: $COMPOSER_USER"
echo "Composer password: $COMPOSER_PASSWORD"
echo
echo "This script will now setup the deployment pipeline using CloudFormation."
echo "Continue? [y/N]"
read CONFIRM_CONTINUE

if ! [[ "$CONFIRM_CONTINUE" =~ ^([yY][eE][sS]|[yY])+$ ]]
then
	echo "Quitting"
    exit
fi

echo "Creating ZIP archive"
FILE="lambda.zip"
cd lambda-deploy
rm -f $FILE
zip -qr $FILE index.js package.json node_modules
FILE_CHECKSUM=`md5 -q $FILE`
LAMBDA_S3_OBJECT_KEY="lambda-functions/deploy-$FILE_CHECKSUM.zip"
export AWS_DEFAULT_REGION="eu-west-1"

echo "Uploading ZIP to S3"
aws s3 mv --sse "aws:kms" $PWD/$FILE s3://codepipeline-eu-west-1-339248251867/$LAMBDA_S3_OBJECT_KEY

cd ..
STACK_NAME="$APP_NAME-deploy"
PARAMS="ParameterKey=AppName,ParameterValue=$APP_NAME"
PARAMS="$PARAMS ParameterKey=RepoName,ParameterValue=$REPO_NAME"
PARAMS="$PARAMS ParameterKey=RepoBranch,ParameterValue=$REPO_BRANCH"
PARAMS="$PARAMS ParameterKey=GitHubToken,ParameterValue=$GITHUB_TOKEN"
PARAMS="$PARAMS ParameterKey=ComposerUser,ParameterValue=$COMPOSER_USER"
PARAMS="$PARAMS ParameterKey=ComposerPassword,ParameterValue=$COMPOSER_PASSWORD"
PARAMS="$PARAMS ParameterKey=LambdaS3ObjectKey,ParameterValue=$LAMBDA_S3_OBJECT_KEY"

aws cloudformation describe-stacks --stack-name "$STACK_NAME" > /dev/null 2>&1
if [ $? -eq 0 ]
then
	echo "Updating CloudFormation stack"
	aws cloudformation update-stack --template-body "file://$PWD/stack-template.yaml" --parameters $PARAMS --stack-name "$STACK_NAME" --capabilities CAPABILITY_NAMED_IAM > /dev/null
	echo -n "In progress... "
	aws cloudformation wait stack-update-complete --stack-name="$STACK_NAME"
else
	echo "Creating CloudFormation stack"
	aws cloudformation create-stack --template-body "file://$PWD/stack-template.yaml" --parameters $PARAMS --stack-name "$STACK_NAME" --capabilities CAPABILITY_NAMED_IAM > /dev/null
	echo -n "In progress... "
	aws cloudformation wait stack-create-complete --stack-name="$STACK_NAME"
fi

# Clear up after ourselves
echo "DONE"
aws s3 rm s3://codepipeline-eu-west-1-339248251867/$LAMBDA_S3_OBJECT_KEY
