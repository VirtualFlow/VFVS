#!/bin/bash

REGION=$1

if [[ "$REGION" == "" ]];
then
    echo "ERROR: must provide AWS region code as argument to script"
    exit
fi

aws cloudformation --region ${REGION} describe-stacks --stack-name vf-vpc --query "Stacks[0].StackStatus" --output text
