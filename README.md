# WordPress CloudFormation template

## Useful commands

Create a new stack:

```
NAME=myapp-$(date +%s); aws cloudformation create-stack --template-body "file://$PWD/wp-stack.yaml" --parameters "file://$PWD/myapp-params.json" --stack-name $NAME --capabilities CAPABILITY_IAM
```

Delete the stack:

```
aws cloudformation delete-stack --stack-name $NAME
```

Use Node version > 6.10
