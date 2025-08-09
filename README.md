# PROG 8870 – Final Project: AWS Infrastructure Automation (Terraform + CloudFormation)

This repo contains a **working reference implementation** for your final project, designed to run **directly in GitHub Codespaces**.

## What you get
- **Terraform**: 4 private S3 buckets, a custom VPC, public EC2 instance (SSH), and a private MySQL RDS (secured from EC2 SG only).
- **CloudFormation**: YAML stacks for S3, EC2 (with networking + outputs), and RDS (public for demo per assignment).
- **Local Terraform backend** (state stored in workspace per assignment).
- **Step-by-step commands** to deploy everything **without errors**.

---

## 0) Open in GitHub Codespaces
1. Fork this repo (or upload it to your GitHub as a new repo).
2. Click **Code → Codespaces → Create codespace on main**.

> Tip: If Terraform/AWS CLI is missing, install:
```bash
sudo apt-get update -y
sudo apt-get install -y unzip jq
curl -fsSL https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip -o tf.zip
sudo unzip -o tf.zip -d /usr/local/bin && rm tf.zip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip && sudo ./aws/install
```

## 1) Configure AWS credentials
From **AWS Academy Learner Lab** (or your account), get temporary credentials and run:
```bash
aws configure
# AWS Access Key ID [None]: AKIA...
# AWS Secret Access Key [None]: xxxxxxxxxxxxx
# Default region name [None]: us-east-1
# Default output format [None]: json
```
Confirm identity:
```bash
aws sts get-caller-identity
```

---

## 2) Terraform deployment

> **Fill `terraform/terraform.tfvars` first** (copy from the provided example). Set a valid **AMI** for your region (Amazon Linux 2023).

```bash
cd terraform

# Copy example and edit
cp terraform.tfvars.example terraform.tfvars
# (edit ec2_ami_id and db_password at minimum)

terraform init
terraform plan
terraform apply -auto-approve
```

**Outputs you'll see:**
- `s3_bucket_names`
- `ec2_public_ip`
- `rds_endpoint`

**SSH to EC2:**
```bash
# Private key is generated at terraform/ec2_${project_prefix}.pem
chmod 400 ec2_prog8870.pem  # adjust if you changed project_prefix
ssh -i ec2_prog8870.pem ec2-user@<ec2_public_ip>
```

> Amazon Linux 2023 uses the `ec2-user` login by default.

---

## 3) CloudFormation – S3 (3 buckets, private + versioning)

```bash
cd cloudformation

aws cloudformation create-stack \
  --stack-name prog8870-s3 \
  --template-body file://cfn-s3.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=ProjectPrefix,ParameterValue=prog8870 \
               ParameterKey=EnableVersioning,ParameterValue=true

aws cloudformation wait stack-create-complete --stack-name prog8870-s3
aws cloudformation describe-stacks --stack-name prog8870-s3 --query "Stacks[0].Outputs"
```

---

## 4) CloudFormation – EC2 (+ VPC/Networking)

Find an AMI ID for your region (same you used in TF is fine). Then:

```bash
aws cloudformation create-stack \
  --stack-name prog8870-ec2 \
  --template-body file://cfn-ec2.yaml \
  --parameters ParameterKey=ProjectPrefix,ParameterValue=prog8870 \
               ParameterKey=AmiId,ParameterValue=ami-xxxxxxxxxxxxxxxxx \
               ParameterKey=InstanceType,ParameterValue=t3.micro

aws cloudformation wait stack-create-complete --stack-name prog8870-ec2
aws cloudformation describe-stacks --stack-name prog8870-ec2 --query "Stacks[0].Outputs"
# Look for Ec2PublicIp in the outputs
```

---

## 5) CloudFormation – RDS (Public for demo per assignment)

```bash
aws cloudformation create-stack \
  --stack-name prog8870-rds \
  --template-body file://cfn-rds.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters ParameterKey=ProjectPrefix,ParameterValue=prog8870 \
               ParameterKey=DBName,ParameterValue=appdb \
               ParameterKey=MasterUsername,ParameterValue=adminuser \
               ParameterKey=MasterUserPassword,ParameterValue='ChangeMeStrong#123'

aws cloudformation wait stack-create-complete --stack-name prog8870-rds
aws cloudformation describe-stacks --stack-name prog8870-rds --query "Stacks[0].Outputs"
# Look for RDSEndpoint and RDSPublicAccessibility in outputs
```

---

## 6) Clean up
```bash
# Terraform
cd terraform
terraform destroy -auto-approve

# CloudFormation
cd ../cloudformation
aws cloudformation delete-stack --stack-name prog8870-s3
aws cloudformation delete-stack --stack-name prog8870-ec2
aws cloudformation delete-stack --stack-name prog8870-rds
```

---

## Submission Checklist
- ✅ GitHub repo link with: `terraform/` & `cloudformation/` folders, README, .gitignore
- ✅ Screenshots:
  - S3 buckets + Versioning
  - EC2 instance + Public IP
  - RDS instance running
  - Terraform plan/apply output
  - CFN stack outputs
- ✅ PPT slides (see `presentation/PROG8870-Demo-Deck.pptx`)

Good luck! 🚀
