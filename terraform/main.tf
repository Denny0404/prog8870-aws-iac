/*
Denish Akbari (8901001)
Root module entrypoint (documentation only).

Terraform loads all *.tf files in this directory:
  - provider.tf     : providers & region
  - variables.tf    : inputs (see terraform.tfvars)
  - vpc.tf          : VPC, subnets, route table, IGW
  - ec2.tf          : key pair, SG, EC2 (public IP)
  - rds.tf          : DB subnet group, SG, RDS MySQL
  - s3.tf           : 4 private S3 buckets + versioning via AWS CLI workaround

Note: main.tf is optional; configuration is modularized above.
*/
