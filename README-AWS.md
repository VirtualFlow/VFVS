## Getting Started with VirtualFlow

This initial setup is required when either VirtualFlow VFLP or VFVS is used. The same AWS setup can be used for both workflows, so it does not need to be duplicated if it is already deployed.

### Create an S3 bucket for data (input and output)

The instructions for this are not covered in this document, but can be found on the [AWS website](https://docs.aws.amazon.com/AmazonS3/latest/userguide/create-bucket-overview.html). As a general best practice, this bucket should not have any public access enabled.


### Set up the AWS CloudFormation Templates

AWS CloudFormation templates allow us to describe infrastructure as code and this allows a setup to be re-created simply. A sample CloudFormation template has been provided in `cfn`. You may choose to setup these in an alternative way, but the template can provide a guide on permissions needed.

Edit `vf-parameters.json` to ensure you have the appropriate S3 parameter (S3BucketName) and KeyName. The S3BucketName is the name of the bucket created in the previous step. The KeyName refers to the EC2 SSH key that you will use to login to the main node that this creates.

```bash
cd cfn/

# Create a large VPC for VirtualFlow (built for us-east-1)
bash create-vf-vpc.sh

# Create the VirtualFlow specific resources
bash create-vf.sh
```

Wait for it to be completed:
```bash
aws cloudformation describe-stacks --stack-name vf --query "Stacks[0].StackStatus"
```

## Getting Started with VirtualFlow Virtual Screening (VFVS)


### Login to the Main Instance

The template above will generate an instance that will be used to run VFVS components. The actual execution will occur in AWS Batch, however, this instance allows staging data, building the docker image, and storing information about the specific VFVS job running. This instance can be stopped when not in use.

The following command and example output show how to retrieve the login hostname for the created instance.
```bash
aws cloudformation describe-stacks --stack-name vf --query "Stacks[0].Outputs"

[
    {
        "Description": "Public DNS name for the main node",
        "ExportName": "vf-MainNodePublicDNS",
        "OutputKey": "MainNodePublicDNS",
        "OutputValue": "ec2-XX-XXX-XXX-XX.compute-1.amazonaws.com"
    }
]
```
SSH into that node to perform operations on AWS Batch. e.g.
```bash
ssh -i ~/.ssh/<keyname>.pem ec2-user@ec2-XX-XXX-XXX-XX.compute-1.amazonaws.com
```

### Upload data for Virtual Screening

VFVS expects that data will be stored in one of two different directory structures, defined as ``hash`` or ``metatranche``. Typically this will be the `metatranche` setting.

#### `metatranche` addressing

In this setting the collections are stored in a format where the collection string “`AECCAACEACDB`” would be stored under the prefix: `AECC/AACE/ACDB-0000`. This data format is the default for the datasets currently available on the VirtualFlow website. Note, if you have downloaded data from the VirtualFlow website, the format it will download in will require extraction of data first prior to placing into the S3 bucket.

The following example bash script will untar the first level of the collections and then upload them to your AWS S3 bucket. (A version of this script is included in the VFVS tools/ directory as well). Before running this, make sure you have the `parallel` command installed.

```bash
#!/bin/bash

object_store_bucket=<s3 bucket>
object_store_ligands_prefix=datasets/set2021
collection_dir=/path/to/where/the/collection/files/are

cd $collection_dir

tempfile=$(mktemp)

for dir in $(ls -d */); do
    echo "$i"
    pushd $dir
    for file in *.tar; do
        echo "  - $file"
        tar -xf $file
    done
    echo "aws s3 sync ${dir} s3://${object_store_bucket}/${object_store_ligands_prefix}/${dir} --exclude *.tar" >> $tempfile
    popd
done

parallel -j 16 --files < $tempfile
```



#### `hash` addressing

This evenly distributes files across different prefixes, which can be beneficial for various filesystems and metadata. This is most appropriate for situations where there may be 1B+ ligands to process. With this addressing mode, the collection string “`AECCAACEACDB`” would be stored under `65/0b/<datasetname>/<datatype>/AECCAACEACDB/0000000.tar.gz`. The hash address (`650b`) is generated from the first 4 characters of a stringified SHA256 hexdigest of `AECCAACEACDB/0000000`.

```bash
[ec2-user ~]$ echo -n "AECCAACEACDB/0000000" | sha256sum | cut -c1-4
650b
```

This output format can be automatically generated from newer versions of VFLP. (If you already have a dataset in the `metatranche` mode it is not recommended to transform it into the `hash` addressing mode.)

### Install VFVS

#### Download the VFVS Code

Login to the main node and execute the following to obtain the latest version of the code.

```bash
git clone -b aws_combined https://github.com/mjkoop/VFVS.git
cd VFVS
```

#### Update the configuration file

The file is in `tools/templates/all.ctrl` and the options are documented in the file itself.

Job Configuration:

- `batchsystem`: Set this to `awsbatch` if you are running with AWS Batch
- `threads_per_docking`: This is how many threads should be run per docking execution. This is almost always '1' since VFVS will run multiple docking executions in parallel for higher efficiency vs more threads per single docking.
- `threads_to_use`: Set this to the number of threads cores that a single job should use.
- `program_timeout`: Seconds to wait until deciding that a single docking execution has timed out.
- `job_storage_mode`: When using Slurm, this must be set to `s3`. Data will be stored in an S3 bucket

Slurm-specific Configuration:

- `aws_batch_prefix`: Prefix for the name of the AWS Batch queues. This is normally 'vf' if you used the CloudFormation template
- `aws_batch_number_of_queues`: Should be set to the number of queues that are setup for AWS Batch. Generally this number is 2 unless you have a large-scale (100K+ vCPUs) setup
- `aws_batch_jobdef`: Generally this is [aws_batch_prefix]-jobdef-vfvs
- `aws_batch_array_job_size`: Target for the number of jobs that should be in a single array job for AWS Batch.
- `aws_ecr_repository_name`: Set it to the name of the Elastic Container Registry (ECR) repository (e.g. vf-vfvs-ecr) in your AWS account (If you used the template it is generally vf-vfvs-ecr)
- `aws_region`: Set to the AWS location code where you are running AWS Batch (e.g. us-east-1 for North America, Northern Virginia)
- `aws_batch_subjob_vcpus`: Set to the number of vCPUs that should be launched per subjob. 'threads_to_use' above should be >= to this value.
- `aws_batch_subjob_memory`: Memory per subjob to setup for the container in MB.
- `aws_batch_subjob_timeout`: Maximum amount of time (in seconds) that a single AWS Batch job should ever run before being terminated.


Job-sizing:

- `ligands_todo_per_queue`: This determines how many ligands should be processed at a minimum per job. A value of '10000' would mean that each subjob with `slurm_cpus` number of CPUs should dock this number of ligands prior to completing. In general jobs should run for approximately 30 minutes or more. How long each docking takes depends on the receptor, ligand being docked, and docking program-specific settings (such as `exhaustiveness`). Submitting a small job to determine how long a docking will take is often a good idea to size these before large runs.


The ligands to be processed should be included in the file within `tools/templates/todo.all`. This file can be automatically generated from the VirtualFlow website.

### Run a Job

#### Prepare Workflow

```bash
cd tools
./vfvs_prepare_folders.py
```

If you have previously setup a job in this directory the command will let you know that it already exists. If you are sure you want to delete the existing data, then run with `--overwrite`

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
./vfvs_submit_jobs_awsbatch.py 1 2
```

Once submitted, AWS Batch will start scaling up resources to meet the requirements of the jobs and begin executing.

#### Monitor Progress

The following command will show the progress of the jobs in AWS Batch. `RUNNABLE` means that the resources are not yet available for the job to run. `RUNNING` means the work is currently being processed.

```bash
./vfvs_get_status.py
```

Additionally, the jobs can be viewed within the AWS Console under 'AWS Batch.' There you can also see the execution of specific jobs and the output they are providing.

Here's an example of a job that is running one collection with 1000 ligands:
```
[ec2-user tools]$ ./vfvs_get_status.py
Looking for updated jobline status - starting

Looking for updated jobline status - done

Looking for updated subtask status - starting

Looking for updated subtask status - done
Generating summary
SUMMARY BASED ON AWS BATCH COMPLETION STATUS (different than actual docking status):

      category     SUBMITTED       PENDING      RUNNABLE      STARTING       RUNNING     SUCCEEDED        FAILED         TOTAL
       ligands             0             0             0             0          1000             0             0          1000
          jobs             0             1             0             0             0             0             0             1
       subjobs             0             0             0             0             1             0             0             1
    vcpu_hours             -             -             -             -             -          0.00          0.00          0.00

vCPU hours total: 0.00
vCPU hours interrupted: 0.00

Active vCPUs: 8
Writing the json status file out
*** Going to move files -- do not interrupt! ***
```

Note that actual charged vCPU hours will be different than what is noted here. This only shows the time a container is running.


## Viewing Results

The results of the job will be placed in the S3 bucket at the location specified within the `all.ctrl`.

#### `metatranche` addressing

Assuming the `metatranche` addressing is being used, the data can be found in the bucket specified under

````
<object_store_job_prefix>/<job_letter>/output/<scenario_name>/results/<metatranche>/<tranche>/<collection_num>.tar.gz
<object_store_job_prefix>/<job_letter>/output/<scenario_name>/logfiles/<metatranche>/<tranche>/<collection_num>.tar.gz
<object_store_job_prefix>/<job_letter>/output/<scenario_name>/summaries/<metatranche>/<tranche>/<collection_num>.tar.gz
<object_store_job_prefix>/<job_letter>/output/ligand-lists/<metatranche>/<tranche>/<collection_num>.status.gz
<object_store_job_prefix>/<job_letter>/output/ligand-lists/<metatranche>/<tranche>/<collection_num>.json.gz
````


## Removing VirtualFlow Installation

#### Remove ECR

The Elastic Container Repository (ECR) will not be automatically be removed by deleting the CloudFormation template if it contains images. Assuming these have been created, these should be removed manually. The `--force` is required if there are images in the repository.


```bash
aws ecr delete-repository --repository-name vf-vfvs-ecr --force
aws ecr delete-repository --repository-name vf-vflp-ecr --force
```

#### Remove ECR

If ECR repositories have been deleted, the template itself can be deleted. This will remove the MainNode, so ensure that all data is backed up as needed. The data in the S3 bucket, which is created outside of this process, will not be touched.







