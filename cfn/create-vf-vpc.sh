#!/bin/bash
aws cloudformation create-stack --stack-name vf-vpc \
--template-body file://vf-vpc.yaml \
--capabilities CAPABILITY_NAMED_IAM \
--parameters file://vf-vpc-parameters.json \
--region us-east-1

