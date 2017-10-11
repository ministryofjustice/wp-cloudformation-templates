# THE INTRANET BRANCH IS DEPRECATED

## WordPress CloudFormation template

The `intranet` branch of this project is **DEPRECATED**.

**DO NOT USE**.  This branch has been left in place for the time being
because there is still a requirement to remove the old test environments
and it is not clear which stack was originally used to create these
resources; there is also a historic stack in
https://github.com/ministryofjustice/intranet-docker-deprecated.

## Useful commands

Create a new stack:

```
NAME=myapp-$(date +%s); aws cloudformation create-stack --template-body "file://$PWD/wp-stack.yaml" --parameters "file://$PWD/myapp-params.json" --stack-name $NAME --capabilities CAPABILITY_IAM
```

Delete the stack:

```
aws cloudformation delete-stack --stack-name $NAME
```
