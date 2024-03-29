---
title: "Solidblocks Hetzner"
date: 2023-04-20T19:00:00
draft: false
tags: ["hetzner", "solidblocks"]
---

After years of shifting workloads to the big cloud providers like AWS or Azure, I am now more often confronted with situations where the deployed cloud infrastructures become unmanageable cost and complexity wise.
A nice, fast and inexpensive alternative for smaller projects is the [Hetzner Cloud](https://cloud.hetzner.com) featuring all basic needed building blocks like VMs, block devices, networking, firewalls and load-balancers.
One major drawback with Hetzner is though, that there is no pendant to the AWS RDS service family, meaning we have to start to self-manage our state (and backups) again.
For not too complex setups, building up on the previously released [Solidblocks RDS](https://pellepelster.github.io/solidblocks/rds/) component, Solidblocks now comes with a Terraform module for Hetzner clouds, providing a fully fledged PostreSQL database with automatic backup and restore capabilities. For more details please visit the [documentation](https://pellepelster.github.io/solidblocks/hetzner/) or have a quick look at the example below, showcasing the most important features.

**main.tf**
```shell

data "aws_s3_bucket" "backup" {
  bucket = "test-rds-postgresql-backup"
}

data "hcloud_volume" "data" {
  name = "rds-postgresql-data"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "hcloud_ssh_key" "ssh_key" {
  name       = "rds-postgresql"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

module "rds-postgresql" {
  source  = "pellepelster/solidblocks-rds-postgresql/hcloud"
  version = "0.1.15"

  name     = "rds-postgresql"
  location = var.hetzner_location

  ssh_keys = [hcloud_ssh_key.ssh_key.id]

  data_volume = data.hcloud_volume.data.id

  backup_s3_bucket     = data.aws_s3_bucket.backup.id
  backup_s3_access_key = var.backup_s3_access_key
  backup_s3_secret_key = var.backup_s3_secret_key

  databases = [
    { id : "database1", user : "user1", password : "password1" }
  ]
}
```

**variables.tf**
```shell
variable "hetzner_location" {
  default = "nbg1"
}

variable "aws_region" {
  default = "eu-central-1"
}


variable "backup_s3_access_key" {
  type = string
}

variable "backup_s3_secret_key" {
  type = string
}
```

