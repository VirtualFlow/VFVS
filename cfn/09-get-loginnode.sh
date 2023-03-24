#!/bin/bash

REGION=$1

if [[ "$REGION" == "" ]];
then
	echo "ERROR: must provide AWS region code as argument to script"
	exit
fi

# For CLI v1 use grep

INSTANCE_ID=`aws cloudformation describe-stacks --stack-name vf-loginnode --query "Stacks[0].Outputs[].[OutputValue]" --region ${REGION} --output text | grep "^i-"`

STATUS=`aws ec2 describe-instances --region ${REGION} --instance-ids ${INSTANCE_ID} --query "Reservations[].Instances[].State.Name" --output text`

if [[ "$STATUS" == "running" ]]; then
	DNS_NAME=`aws ec2 describe-instances --region ${REGION} --instance-ids ${INSTANCE_ID} --query "Reservations[].Instances[].PublicDnsName" --output text`
	echo $DNS_NAME
	echo ""
	echo "ssh -i <path to key> ec2-user@$DNS_NAME"
	echo ""
else
	echo "$INSTANCE_ID is not in state running ($STATUS)"
fi

