#!/bin/bash

ME=$(basename "$0")

##
# Update a deployment pipeline stack template
# Keeping all parameters and the Lambda deployment function the same
##

USAGE="Update a deployment pipeline stack template

Usage:
  $ME <stack_name> [<stack_name> ...]

Parameters:
  <stack_name>      Name of the deployment stack.
  Update multiple stacks by supplying multiple space separated stack names.

Example usage:
  $ME example-deploy anotherapp-deploy
"

if [ -z $1 ]; then
	echo "$USAGE"
	exit 1
fi

PARAM_KEYS=(AppName RepoName RepoBranch GitHubToken ComposerUser ComposerPassword LambdaS3ObjectKey)
PARAMS=""
for KEY in "${PARAM_KEYS[@]}"; do
	PARAMS="$PARAMS ParameterKey=$KEY,UsePreviousValue=true"
done

for STACK_NAME in "$@"; do
    aws cloudformation update-stack --region eu-west-1 --template-body "file://$PWD/stack-template.yaml" --parameters $PARAMS --stack-name "$STACK_NAME" --capabilities CAPABILITY_NAMED_IAM
done
