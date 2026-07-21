# DevOps Assessment

This project contains three services:

* `quotes` which serves a random quote from `quotes/resources/quotes.json`
* `newsfeed` which aggregates several RSS feeds together
* `front-end` which calls the two previous services and displays the results.

The services are provided as docker images. This README documents the steps to build the images and provision the infrastructure for the services.

# Development and operations tools setup

There are 2 options for getting the right tools on developer's laptop:
 * **quick** leverage Docker+Dojo. Requires only to install docker and dojo on your laptop.
 * **manual** requires to install all tools manually

 The rest of this file describes the manual way, please refer to [README.md](README.md) for the other option.

## Manual setup

You need all the tools below installed locally:
### Prerequisites to run the Python applications

 * make
 * Python and a virtualenv

### Prerequisites for running infrastructure code

 * make
 * local docker daemon
 * docker buildx addon
 * terraform 1.2.7
 * ssh-keygen
 * azure cli

 ### Installing docker buildx

This is a multi arch build tool to support x86 builds on ARM based laptops

More details here: https://github.com/abiosoft/colima/discussions/273

# Infrastructure setup

This is a multi-step guide to setup some base infrastructure, and then, on top of it, the test environment for the newsfeed application.

## Base infrastructure setup

With an assumption that we have a new, empty AWS account, we need to provision some base infrastructure just one time.
These steps will provision:
 * terraform backend in resource_group_name, storage_account_name and container_name
 * a minimal VPC with 3 subnets
 * ACR repositories for docker images

## Build docker images

Artifacts from previous stage will be packaged into docker images, then pushed to ACR.

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

Before applications can be deployed on Azure, the docker images have to be pushed:
```sh
make push
```

## Provision services

Then, we can provision the backend and front-end services:
```sh
make backend-support.infra
make base.infra
make news.infra
```

## Provision all services
```sh
make deploy_interview
```

Terraform will print the output with URL of the front_end server, e.g.
```
Outputs:

frontend_url = http://34.244.219.156:8080
```

## Delete services

To delete the deployment provisioned by terraform, run following commands:
```sh
make backend-support.deinfra
make base.deinfra
make news.deinfra
```

## Delete all services
```sh
make destroy_interview
```
