---
title: "Solidblocks Shell Terraform"
date: 2023-03-01T19:00:00
draft: false
tags: ["pdx"]
---

A common problem when provisioning infrastructure with [Terraform](https://www.terraform.io/) is the inherent bootstrapping problem imposed by the fact that Terraform needs some kind of storage to store its [state](https://developer.hashicorp.com/terraform/language/state). 
In an ideal world Terraform would be able to provision its state backends using infrastructure as code defined in Terraform itself. In a more real world you are often confronted with the question "Where to store the initial state needed to provision the first resources?".

Tools like [terragrunt](https://terragrunt.gruntwork.io/) can help in this situation, or you can resort to soring the state encrypted in a git repository using [git-crypt](https://manpages.ubuntu.com/manpages/jammy/man1/git-crypt.1.html) for example. 

But those solutions come with additional complexity and its own set of bootstrapping problems.

As a standalone and no-dependency alternative [Solidblocks Shell Terraform](https://pellepelster.github.io/solidblocks/shell/terraform/) components offer an easy way to eliminate this problem.

Using simple shell based utilities for [creating S3 Buckets](https://pellepelster.github.io/solidblocks/shell/aws/#aws_bucket_ensure) and [creating DynamoDB tables](https://pellepelster.github.io/solidblocks/shell/aws/#aws_dynamodb_ensure) the function `terraform_aws_state_backend(name)` will create a S3 bucket and a DynamoDB table that can directly be used for terraform state backend storage and locking.

```shell
source "software.sh"
source "terraform.sh"

software_ensure_terraform
software_set_export_path

terraform_aws_state_backend "my-project"
```

using Terraform's partial configuration feature where parts of the state backend configuration can be externalized, we can use the created resources to init the terraform state

```shell
terraform init -reconfigure \
  -backend-config="bucket=my-project" \
  -backend-config="dynamodb_table=my-project"
```

The Terraform file just needs to define the parts of that state backend that are not provided via the command line arguments


```terraform
terraform {
  backend "s3" {
    key = "my-project/terraform.state"
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.56.0"
    }
  }
}

provider "aws" {
}

# [...]
```
