---
title: "Solidblocks RDS"
date: 2022-10-01T19:00:00
draft: false
---

Being a freelance consultant for some time now, I find myself frequently coming back to one of my [older posts](/posts/hetzner-rds-postgres/) on how to run a PostgreSQL database in the cloud, where the cloud is not one of the big ones that already offer a dedicated managed database service. 
Although for example [AWS RDS](https://aws.amazon.com/rds/) is an excellent and stable service, it can sometimes be a little too much (and to pricey as well). 

For the re-occurring tasks of my daily work (and maintaining databases is definitely one of them) I invested some time to create a tested, easy to configure and/or reusable version of that particular task. The collection is called [Solidblocks](https://github.com/pellepelster/solidblocks), its documentation can be found here [https://pellepelster.github.io/solidblocks/](https://pellepelster.github.io/solidblocks/)

This particular post highlights an easy to user PostgreSQL docker container, that fits the need for a quick to deploy PostgreSQL database with an adequate backup solution for data safety. 
You can read the [documentation](https://pellepelster.github.io/solidblocks/rds/) with all the nitty-gritty details, here a quick walk-through to give you an impression:

**Start the database**
```shell
$ mkdir postgres_{data,backup} && sudo chown 10000:10000 postgres_{data,backup}

$ docker run \
    --name instance1 \
    -e DB_INSTANCE_NAME=instance1 \
    -e DB_DATABASE_db1=database1 \
    -e DB_USERNAME_db1=user1 \
    -e DB_PASSWORD_db1=password1 \
    -e DB_BACKUP_LOCAL=1 \
    -v "$(pwd)/postgres_backup:/storage/backup" \
    -v "$(pwd)/postgres_data:/storage/data" \
    pellepelster/solidblocks-rds-postgresql:v0.0.60
```

**Trigger a full backup**

```shell
$ docker exec instance1 /rds/bin/backup-full.sh
```

**Stop database and remove data dir**
```shell
$ docker rm --force instance1
$ sudo rm -rf postgres_data
$ mkdir postgres_data && sudo chown 10000:10000 postgres_data
```

**Start database again**
It will recover from the latest available backup
```shell
$ docker run \
--name instance1 \
-e DB_INSTANCE_NAME=instance1 \
-e DB_DATABASE_db1=database1 \
-e DB_USERNAME_db1=user1 \
-e DB_PASSWORD_db1=password1 \
-e DB_BACKUP_LOCAL=1 \
-v "$(pwd)/postgres_backup:/storage/backup" \
-v "$(pwd)/postgres_data:/storage/data" \
pellepelster/solidblocks-rds-postgresql:v0.0.60
```

