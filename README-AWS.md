## Getting Started with VirtualFlow

This initial setup is required when either VirtualFlow VFLP or VFVS is used. The same AWS setup can be used for both workflows, so it does not need to be duplicated if it is already deployed.

### Create an S3 bucket for data (input and output)

The instructions for this are not covered in this document, but can be found on the [AWS website](https://docs.aws.amazon.com/AmazonS3/latest/userguide/create-bucket-overview.html). As a general best practice, this bucket should not have any public access enabled.


### Set up the AWS CloudFormation Templates

AWS CloudFormation templates allow us to describe infrastructure as code and this allows a setup to be re-created simply. A sample CloudFormation templates have been provided in `cfn`. You may choose to setup these in an alternative way, but the template can provide a guide on permissions needed.


Settings are in `params/<region>/`
* `vpc-parameters.json` -- VPC setup
* `vf-parameters.json` -- Batch infrastructure setup
* `vf-loginnode-parameters.json` -- Login node setup

At a minimum the following two parameters should be updated:
* `S3BucketName` is the name of the bucket created in the previous step. (`vf-parameters.json` and `vf-loginnode-parameters.json`)
* `KeyName` refers to the EC2 SSH key that you will use to login to the main node that this creates. (``vf-loginnode-parameters.json``)


All scripts require the AWS region name as the first argument.
e.g. `./00a-create-vpc.sh us-east-1`
(for US-East-1, Northern Virginia region)


```bash
cd cfn/

# Create a large VPC for VirtualFlow
./00a-create-vpc.sh us-east-2

# Check to see if it has completed (It will say CREATE_COMPLETE when complete)
./00b-create-vpc-status.sh us-east-2

# Create the VirtualFlow specific resources
./01a-create-batchresources.sh us-east-2

# Check to see if it has completed (It will say CREATE_COMPLETE when complete)
./01b-create-batchresources-status.sh us-east-2
```

These are the only resources required to run VirtualFlow. Most users will be interested to have a login node where the VirtualFlow environment can be installed and jobs can be run from. This requires a Docker setup to be available. We recommend starting a login node to do this task.


```bash
cd cfn/

# Create a login node for VirtualFlow
./02a-create-loginnode.sh us-east-2

# Check to see if it has completed (It will say CREATE_COMPLETE when complete)
./02b-create-loginnode-status.sh us-east-2
```

An example script to shutdown the login node when not in use is also provided. *Do not do this now, unless you do not plan to complete the installation*. Note that "stopping" the instance will stop the instance cost from running being charged, however, charges related to the EBS volume (the storage) will still be charged. If you do not need the data on the instance, it can be deleted (see bottom of doc):
```bash
./10-stop-loginnode.sh us-east-2
```

Similarly, when you return and want to re-start the login node, there is a sample script:
```bash
./11-start-loginnode.sh us-east-2```
```


## Getting Started with VirtualFlow Virtual Screening (VFVS)


### Login to the Main Instance

The template above will generate an instance that will be used to run VFVS components. The actual execution will occur in AWS Batch, however, this instance allows staging data, building the docker image, and storing information about the specific VFVS job running. This instance can be stopped when not in use (.

The following command and example output show how to retrieve the login hostname for the created instance.
```bash
[ec2-user@ip-172-31-56-4 cfn_templates_v0.6-matt]$ ./09-get-loginnode.sh us-east-2
ec2-XX-XXX-XXX-X.us-east-2.compute.amazonaws.com

ssh -i <path to key> ec2-user@ec2-XX-XXX-XXX-X.us-east-2.compute.amazonaws.com
```
SSH into that node to perform operations on VirtualFlow. e.g.
```bash
ssh -i ~/.ssh/<keyname>.pem ec2-user@ec2-XX-XXX-XXX-X.us-east-2.compute.amazonaws.com
```

### Upload data for Virtual Screening

VFVS expects that data will be stored in one of two different directory structures, defined as ``hash`` or ``metatranche``. Typically this will be the `metatranche` setting.

#### `metatranche` addressing

In this setting the collections are stored in a format where the collection string “`AECC_AACE_ACDB`” would be stored under the prefix: `AECC/AACE/ACDB`.

#### `hash` addressing

This evenly distributes files across different prefixes, which can be beneficial for various filesystems and metadata. This is most appropriate for situations where there may be 1B+ ligands to process. With this addressing mode, the collection string “`AECCAACEACDB`” would be stored under `65/0b/<datasetname>/<datatype>/AECCAACEACDB/0000000.tar.gz`. The hash address (`650b`) is generated from the first 4 characters of a stringified SHA256 hexdigest of `AECCAACEACDB/0000000`.

```bash
[ec2-user ~]$ echo -n "AECCAACEACDB/0000000" | sha256sum | cut -c1-4
650b
```

This format is used for the latest version of the REAL dataset. (If you already have a dataset in the `metatranche` mode it is not recommended to transform it into the `hash` addressing mode.)

### Install VFVS

#### Download the VFVS Code

Login to the main node and execute the following to obtain the latest version of the code.

```bash
git clone https://github.com/VirtualFlow/VFVS.git -b python-develop
cd VFVS
```

#### Update the configuration file

The file is in `tools/templates/all.ctrl` and the options are documented in the file itself.

Job Configuration:

- `batchsystem`: Set this to `awsbatch` if you are running with AWS Batch
- `threads_per_docking`: This is how many threads should be run per docking execution. This is almost always '1' since VFVS will run multiple docking executions in parallel for higher efficiency vs more threads per single docking.
- `threads_to_use`: Set this to the number of threads cores that a single job should use.
- `program_timeout`: Seconds to wait until deciding that a single docking execution has timed out.
- `job_storage_mode`: When using AWS Batch, this must be set to `s3`. Data will be stored in an S3 bucket

AWS Batch-specific Configuration:

- `aws_batch_prefix`: Prefix for the name of the AWS Batch queues. This is normally 'vf' if you used the CloudFormation template
- `aws_batch_number_of_queues`: Should be set to the number of queues that are setup for AWS Batch. Generally this number is 1 unless you have a large-scale (100K+ vCPUs) setup
- `aws_batch_jobdef`: Generally this is [aws_batch_prefix]-jobdef-vfvs
- `aws_batch_array_job_size`: Target for the number of jobs that should be in a single array job for AWS Batch.
- `aws_ecr_repository_name`: Set it to the name of the Elastic Container Registry (ECR) repository (e.g. vf-vfvs-ecr) in your AWS account (If you used the template it is generally vf-vfvs-ecr)
- `aws_region`: Set to the AWS location code where you are running AWS Batch (e.g. us-east-2 for North America, Ohio)
- `aws_batch_subjob_vcpus`: Set to the number of vCPUs that should be launched per subjob. 'threads_to_use' above should be >= to this value.
- `aws_batch_subjob_memory`: Memory per subjob to setup for the container in MB.
- `aws_batch_subjob_timeout`: Maximum amount of time (in seconds) that a single AWS Batch job should ever run before being terminated.
- `athena_s3_location`: Needed if AWS Athena is used to simplify ranking of output via the `vfvs_get_top_results.py` script. Often using the same bucket as you use for the job data is preferred (e.g. s3://mybucket/athena/)


Job-sizing:

- `ligands_todo_per_queue`: This determines how many ligands should be processed at a minimum per job. A value of '10000' would mean that each subjob with `aws_batch_subjob_vcpus` number of CPU cores should dock this number of ligands prior to completing. In general jobs should run for approximately 30 minutes or more. How long each docking takes depends on the receptor, ligand being docked, and docking program-specific settings (such as `exhaustiveness`). Submitting a small job to determine how long a docking will take is often a good idea to size these before large runs.


The ligands to be processed should be included in the file within `tools/templates/todo.all`. This file can be automatically generated from the VirtualFlow website.

### Run a Job

#### Prepare Workflow

```bash
cd tools
./vfvs_prepare_folders.py
```

If you have previously setup a job in this directory the command will let you know that it already exists. If you are sure you want to delete the existing data, then run with `--overwrite`.

Once you run this command the workflow is defined using the current state of `all.ctrl` and `todo.all`. Changes to those files at this point will not be used unless `vfvs_prepare_folders.py` is run again.

#### Build Docker Image (first time only)

This is only required once (or if execution files have been changed and need to be updated). This will prepare the container that AWS Batch will use to run VFVS.

```bash
./vfvs_build_docker.sh
```

If you run into errors, it may be because the user you have logged in as does not have permission to run docker.


#### Verify Collections

To ensure that all of the collections can be found in the S3 bucket, the `vfvs_verify_collections.py` script can be used to determine if there are any collections in the `todo.all` that do not seem to be available in the S3 bucket and path set.


#### Generate Workunits

VFVS can process billions of ligands, and in order to process these efficiently it is helpful to segment this work into smaller chunks. A workunit is a segment of work that contains many 'subjobs' that are the actual execution elements. Often a workunit will have approximately 200 subjobs and each subjob will contain about 60 minutes worth of computation.

```bash
./vfvs_prepare_workunits.py
```

Pay attention to how many workunits are generated. The final line of output will provide the number of workunits.

#### Submit the job to run on AWS Batch

The following command will submit workunits 1 and 2. The default configuration with
AWS Batch will use 200 subjobs per workunit, so this will submit 2x200 (400) subjobs
(assuming that each workunit was full). Each subjob takes 8 vCPUs when running.

How long each job takes will be dependent on the parameters that were set as part of the `all.ctrl` and the docking scenarios themselves.

```bash
./vfvs_submit_jobs.py 1 2
```

Once submitted, AWS Batch will start scaling up resources to meet the requirements of the jobs and begin executing.

#### Monitor Progress

The following command will show the progress of the jobs in AWS Batch. `RUNNABLE` means that the resources are not yet available for the job to run. `RUNNING` means the work is currently being processed.

```bash
./vfvs_get_status.py
```

Additionally, the jobs can be viewed within the AWS Console under 'AWS Batch.' There you can also see the execution of specific jobs and the output they are providing.

Here's an example of a job that is a tiny job with 42 ligands:
```bash
[ec2-user@ip-10-0-7-126 tools]$ ./vfvs_get_status.py
Getting workunit status
Getting subjob status
Downloading result files

-----------------------------------------------------------------
AWS Batch Progress
-----------------------------------------------------------------

Docking count is inaccurate for sensor screens. Correct value will
be in 'Completed Summary' when finished.

         Status   Workunits        Subjobs      Dockings (est.)
      SUBMITTED       0               0                 0
        PENDING       0               0                 0
       RUNNABLE       0               0                 0
       STARTING       0               0                 0
        RUNNING       0               0                 0
      SUCCEEDED       1               1                42
         FAILED       0               0                 0

Active vCPUs: 0

-----------------------------------------------------------------
Completed Summary
-----------------------------------------------------------------

* Total Dockings  : 42
  - Succeeded     : 42
  - Failed        : 0
* Skipped ligands : 0
* Failed Downloads: 0 (est. 0 dockings)

* vCPU seconds per docking: 0.91
* vCPU hours total        : 0.01
* vCPU hours interrupted  : 0.00
```

This shows the AWS Batch status, not necessarily if the actual docking succceeded. You can see detailed results with `--detailed`:

```bash
[ec2-user@ip-10-0-7-126 tools]$ ./vfvs_get_status.py --detailed
Getting workunit status
Getting subjob status
Downloading result files

-----------------------------------------------------------------
AWS Batch Progress
-----------------------------------------------------------------

Docking count is inaccurate for sensor screens. Correct value will
be in 'Completed Summary' when finished.

         Status   Workunits        Subjobs      Dockings (est.)
      SUBMITTED       0               0                 0
        PENDING       0               0                 0
       RUNNABLE       0               0                 0
       STARTING       0               0                 0
        RUNNING       0               0                 0
      SUCCEEDED       1               1                42
         FAILED       0               0                 0

Active vCPUs: 0

-----------------------------------------------------------------
Completed Summary
-----------------------------------------------------------------

* Total Dockings  : 42
  - Succeeded     : 42
  - Failed        : 0
* Skipped ligands : 0
* Failed Downloads: 0 (est. 0 dockings)

* vCPU seconds per docking: 0.91
* vCPU hours total        : 0.01
* vCPU hours interrupted  : 0.00
```


Note that actual charged vCPU hours will be different than what is noted here. This only shows the time a container is running.


## Viewing Results


### Summary (with AWS Athena)

In order to use AWS Athena, the `athena_s3_location` setting must have been set in the `all.ctrl`. The `vfvs_get_top_results.py` script will provide the top scoring ligands from the runs.

If the `--top N` flag is used, only the top *N* number of scores will be returned.

```bash
[ec2-user@ip-10-0-7-126 tools]$ ./vfvs_get_top_results.py --top 10 --download
Running query in AWS Athena

Waiting on createdb if needed (...)
Waiting on dropping of old table (...)
Waiting on create table (..)
Waiting on query (...)

STATUS: SUCCEEDED
Output location: s3://xyz.csv
download: s3://xyz.csv to ../output-files/<scenario-name>.top-10.csv
```

If you have more than one scenario, the scenario must be selected by `--scenario-name`


### All Results

The results of the job will be placed in the S3 bucket at the location specified within the `all.ctrl`.

The data can be found in the bucket specified under:

````
<object_store_job_prefix>/<job_letter>/<scenario_name>/csv/<workunit>/<subjob_id>.csv.gz
<object_store_job_prefix>/<job_letter>/<scenario_name>/logs/<workunit>/<subjob_id>.tar.gz
<object_store_job_prefix>/<job_letter>/<scenario_name>/parquet/<workunit>/<subjob_id>.parquet
<object_store_job_prefix>/<job_letter>/summary/<workunit>/<subjob_id>.json
````


## Removing VirtualFlow Installation

```
./97-delete-loginnode.sh <region>
./98-delete-vf.sh <region>
```

Note that you cannot delete the VPC until the previous two
stacks have completed deleting. You can see the status of
those stacks:

```
./01b-create-batchresources-status.sh <region>
./02b-create-loginnode-status.sh <region>
```

Once those are complete you can remove the VPC stack:
```
./99-delete-vpc.sh
```

Note, if you also want to remove your data you must also manually delete the S3 bucket that you created.






