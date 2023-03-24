#!/bin/bash

REGION=$1

if [[ "$REGION" == "" ]];
then
    echo "ERROR: must provide AWS region code as argument to script"
    exit
fi

aws ecr delete-repository --repository-name vf-vflp-ecr --force --region ${REGION}
aws ecr delete-repository --repository-name vf-vfvs-ecr --force --region ${REGION}

aws cloudformation delete-stack --stack-name vf \
--region ${REGION}

