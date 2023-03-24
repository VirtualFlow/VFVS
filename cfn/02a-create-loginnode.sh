#!/bin/bash

REGION=$1

if [[ "$REGION" == "" ]];
then
	echo "ERROR: must provide AWS region code as argument to script"
	exit
fi


if [[ ! -e yaml/vf-loginnode.yaml ]];
then
	echo "ERROR: yaml/vf-loginnode.yaml is not setup yet"
	exit;
fi

if [[ ! -e params/${REGION}/vf-loginnode-parameters.json ]];
then
	echo "ERROR: params/${REGION}/vf-loginnode-parameters.json is not setup yet"
	exit;
fi


aws cloudformation create-stack --stack-name vf-loginnode \
--template-body file://yaml/vf-loginnode.yaml \
--capabilities CAPABILITY_NAMED_IAM \
--parameters file://params/${REGION}/vf-loginnode-parameters.json \
--region ${REGION}

