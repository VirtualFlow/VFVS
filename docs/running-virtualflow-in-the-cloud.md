# Running VirtualFlow in the Cloud

## **Introduction**

Due to its flexible architecture, VirtualFlow is able to not only run on Linux computer clusters and supercomputers, but also runs natively on cloud computing platforms such as

* Google Cloud Platform&#x20;
* Amazon Web Services
* Microsoft Azure

This is due to the circumstance that VirtualFlow operates by using resource managers (also called batch systems) such as SLURM, and these batch systems are able to run on many cloud computing platforms as the three mentioned above.



## **Google Cloud Platform (GCP)**

To run VirtualFlow on the Google Cloud Platform, we recommend to use the GCP version of the Slurm resource manager, which runs out of the box on the GCP. To get started with Slurm on the GCP, we recommend the following page:

* [https://cloud.google.com/blog/products/compute/hpc-made-easy-announcing-new-features-for-slurm-on-gcp](https://cloud.google.com/blog/products/compute/hpc-made-easy-announcing-new-features-for-slurm-on-gcp)

After the Slurm cluster is running on the GCP, one can use VirtualFlow as on any other Linux cluster.

For large-scale computations using many virtual machines, a fast shared cluster file system is needed. We recommend to use either [Lustre](https://cloud.google.com/blog/products/storage-data-transfer/introducing-lustre-file-system-cloud-deployment-manager-scripts) or [Elastifile](https://cloud.google.com/blog/products/storage-data-transfer/scale-storage-out-with-new-elastifile-cloud-file-service-for-gcp) for this purpose.&#x20;

## Amazon Web Services (AWS)

To run VirtualFlow on Amazon Web Services, we recommend to use AWS ParallelCluster, which allows to employ to run the SGE, TORQE, and Slurm resource managers conventiently in on AWS. All three of them are supported by VirtualFlow, but we recommend to use Slurm, as it is most common and modern, and best supported resource manager. We recommend the following page to get started with AWS ParallelCluster.

* [https://aws.amazon.com/blogs/opensource/aws-parallelcluster/](https://aws.amazon.com/blogs/opensource/aws-parallelcluster/)

After the Slurm cluster is running on AWS, one can use VirtualFlow as on any other Linux cluster.

For large-scale computations using many virtual machines, a fast shared cluster file system is needed. We recommend to use [FSx for Lustre](https://aws.amazon.com/fsx/lustre/) for this purpose.



