# lambda-deploy

This AWS Lambda function deploys a docker image to an ECS service using CloudFormation.

It takes 3 input assets:

* CloudFormation template
* Application specific deployment params (like db credentials)
* The tag that was applied to the docker image

It also takes a JSON object as the user parameter string, with the expected keys:

* **AppName**: The name of the application to deploy
* **Env**: The environment to deploy to (dev|staging|prod)

```json
{
	"AppName": "exampleapp",
	"Env": "dev"
}
```

# TODO:

* Add better fail case if required files are not found
* Create a registry tag on deploy to show what revision has been deployed to each enviroment (see https://docs.docker.com/registry/spec/api/)
* Wait for cf stack update to complete (may need lambda continuations)
* Send message to hipchat on deploy
* Send message to hipchat when manual approval needed
