# Infrastructure Assessment

This project contains three services:

* `quotes` which serves a random quote from `quotes/resources/quotes.json`
* `newsfeed` which aggregates several RSS feeds together
* `front-end` which calls the two previous services and displays the results.

The services are provided as docker images. This README documents the steps to build the images and provision the infrastructure for the services.

# Development and operations tools setup

There are 2 options for getting the right tools on developer's laptop:
 * **quick** leverage Docker+Dojo. Requires only to install docker and dojo on your laptop.
 * **manual** requires to install all tools manually

 The rest of this file describes the quick way, please refer to [MANUAL_SETUP.md](MANUAL_SETUP.md) for the other option.


This project is also using `make`, so ensure that you have that on your PATH too.

# Infrastructure setup

This is a multi-step guide to setup some base infrastructure, and then, on top of it, the test environment for the newsfeed application.

## Base infrastructure setup

With an assumption that we have a new, empty Azure subscription, we need to provision some base infrastructure just one time.
These steps will provision:
 * terraform backend in in resource_group_name, storage_account_name and container_name
 * a minimal VPC with 2 subnets
 * ACR repositories for docker images

### Setup Azure credentials
The interviewer will send you an email with Azure credentials, which you should export in your shell.

```sh
export CODE_PREFIX=****
```

Now run:
```sh
source randomize.sh && randomize
make backend-support.infra
make base.infra
```

## Build docker images

Artifacts from previous stage will be packaged into docker images, then pushed to ECR.

Each application has its own image. Individual image can be built with:

```sh
make <app-name>.docker
# for example:
make front-end.docker
```

But you can build all images at once with

```sh
make docker
```

## Push docker images

Before applications can be deployed on AWS, the docker images have to be pushed:

```sh
make push
```

## Provision services

Then, we can provision the backend and front-end services:

```sh
make news.infra
```

Terraform will print the output with URL of the front_end server, e.g.

```
Outputs:

frontend_url = http://34.244.219.156:8080
```

## Provision all services
```sh
make deploy_interview
```

## Delete services

To delete the deployment provisioned by terraform, run following commands:

```sh
make news.deinfra
```
