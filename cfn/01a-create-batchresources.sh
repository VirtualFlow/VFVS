#!/bin/bash

REGION=$1

if [[ "$REGION" == "" ]];
then
	echo "ERROR: must provide AWS region code as argument to script"
	exit
fi


if [[ ! -e yaml/vf.yaml ]];
then
	echo "ERROR: yaml/vf.yaml is not setup yet"
	exit;
fi

if [[ ! -e params/${REGION}/vf-parameters.json ]];
then
	echo "ERROR: params/${REGION}/vf-parameters.json is not setup yet"
	exit;
fi


aws cloudformation create-stack --stack-name vf \
--template-body file://yaml/vf.yaml \
--capabilities CAPABILITY_NAMED_IAM \
--parameters file://params/${REGION}/vf-parameters.json \
--region ${REGION}

