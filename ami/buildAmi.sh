#!/bin/bash
packer build \
    -var 'aws_access_key=' \
    -var 'aws_secret_key=' \
    -var 'aws_region=' \
    -var 'source_ami=ami-' \
    -var 'subnet_id=' \
    -var 'ami_users=' \
    ami.json