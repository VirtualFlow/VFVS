#!/bin/bash

REGION=$1

if [[ "$REGION" == "" ]];
then
    echo "ERROR: must provide AWS region code as argument to script"
    exit
fi

aws cloudformation delete-stack --stack-name vf-vpc \
--region ${REGION}

