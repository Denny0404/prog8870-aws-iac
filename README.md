# AWS Infrastructure Automation – Denish Akbari (8901001)

**Course:** PROG 8870 — Final Project  
**Student:** Denish Akbari (8901001)  
**Region:** `us-east-1`  
**Project Prefix (used in all names):** `denishakbari-8901001`

This guide is a **complete A→Z runbook** to recreate the project quickly in GitHub Codespaces using an AWS Academy Learner Lab account. It covers **Terraform** (VPC, EC2, RDS, S3) and **CloudFormation** (S3, EC2, RDS), verification, screenshots to capture, and cleanup. All commands are copy-paste ready.

---

## 0) Repository layout (expected)

```
prog8870-aws-iac/
├─ terraform/
│  ├─ provider.tf
│  ├─ variables.tf
│  ├─ vpc.tf
│  ├─ ec2.tf
│  ├─ rds.tf
│  ├─ s3.tf                # uses CLI via null_resource local-exec (Academy S3 policy workaround)
│  ├─ terraform.tfvars     # values (db_password masked in screenshots)
│  └─ main.tf (optional, header comment only)
├─ cloudformation/
│  ├─ cfn-s3.yaml
│  ├─ cfn-ec2.yaml
│  └─ cfn-rds.yaml
├─ submission/             # CLI outputs & evidence for grading
└─ README.md               # (this guide can replace/augment)
```

> If any file is missing/corrupted, use the templates in **Appendix A** below to restore.

---

## 1) One-time environment setup

Open the repo in **GitHub Codespaces**. Then:

```bash
# Go to repo root
cd /workspaces/prog8870-aws-iac

# Handy tools
sudo apt-get update -y
sudo apt-get install -y unzip jq dos2unix tree

# Terraform (if missing)
terraform -version || {
  curl -fsSL https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip -o tf.zip
  sudo unzip -o tf.zip -d /usr/local/bin
  rm tf.zip
}

# AWS CLI v2 (if missing)
aws --version || {
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install
}
```

### 1.1 Configure AWS Academy credentials (expire every session)
From **Learner Lab → AWS Details → CLI** copy the 3 values and run:

```bash
rm -f ~/.aws/credentials ~/.aws/config
mkdir -p ~/.aws
```

```bash
aws configure set aws_access_key_id     YOUR_ACCESS_KEY_ID     --profile academy
aws configure set aws_secret_access_key YOUR_SECRET_ACCESS_KEY --profile academy
aws configure set aws_session_token     YOUR_SESSION_TOKEN     --profile academy
aws configure set region                us-east-1              --profile academy

export AWS_PROFILE=academy
aws sts get-caller-identity
```

Expected: JSON with your `Account` and `Arn`.

---

## 2) Personalize variables

We will use this prefix in both Terraform and CloudFormation:

```bash
export PREFIX="denishakbari-8901001"
export REGION="us-east-1"
```

Fetch a recent **Amazon Linux 2023** AMI ID:

```bash
AMI=$(aws ec2 describe-images \
  --owners amazon \
  --region $REGION \
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" --output text)
echo "AMI: $AMI"
```
```bash
AMI=$(aws ec2 describe-images \
  --owners amazon \
  --region $AWS_DEFAULT_REGION \
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
  --query "sort_by(Images, &CreationDate)[-1].ImageId" --output text)

echo "AMI ID: $AMI"
```

---

## 3) Terraform — deploy core infra

```bash
cd /workspaces/prog8870-aws-iac/terraform

# Ensure tfvars exists and is cleanly set
[ -f terraform.tfvars ] || cp terraform.tfvars.example terraform.tfvars
sed -i '/^ec2_ami_id/d;/^db_password/d;/^project_prefix/d;/^region/d' terraform.tfvars

cat >> terraform.tfvars <<EOF
ec2_ami_id      = "${AMI}"
db_password     = "ChangeMeStrong#123!"
project_prefix  = "${PREFIX}"
region          = "${REGION}"
EOF

# Deploy
terraform init -upgrade
terraform validate
terraform apply -auto-approve
```

### 3.1 Verify & capture evidence

```bash
# Outputs
terraform output

# Save for submission
mkdir -p ../submission
terraform output > ../submission/01_terraform_outputs.txt
terraform state list > ../submission/02_terraform_state.txt

# S3 (first bucket) – private + versioning
B=$(terraform output -json s3_bucket_names | jq -r '.[0]')
echo "Bucket: $B" | tee ../submission/00_bucket_name.txt
aws s3api get-public-access-block --bucket "$B" | tee ../submission/03_s3_public_access.json
aws s3api get-bucket-versioning  --bucket "$B" | tee ../submission/04_s3_versioning.json

# EC2 table
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${PREFIX}-ec2" \
  --query 'Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,AZ:Placement.AvailabilityZone,State:State.Name,PublicIP:PublicIpAddress}' \
  --output table | tee ../submission/05_tf_ec2_table.txt

# Optional “no drift” proof
terraform apply -refresh-only -auto-approve
```

> **SSH (demo):**
>
> ```bash
> cd /workspaces/prog8870-aws-iac/terraform
> ls -1 *.pem
> chmod 400 *.pem
> ssh -i <your_pem_from_above> ec2-user@$(terraform output -raw ec2_public_ip)
> ```

---

## 4) CloudFormation — S3, EC2, RDS

```bash
cd /workspaces/prog8870-aws-iac/cloudformation
export PREFIX="denishakbari-8901001"
```

### 4.1 Validate templates (sanity check)

```bash
export AWS_PROFILE=academy
export AWS_DEFAULT_REGION=us-east-1   # << required
aws sts get-caller-identity
```

```bash
aws cloudformation validate-template --template-body file://cfn-s3.yaml
aws cloudformation validate-template --template-body file://cfn-ec2.yaml
aws cloudformation validate-template --template-body file://cfn-rds.yaml
```

If validation fails, restore from **Appendix A**.

```bash
aws cloudformation delete-stack --stack-name ${PREFIX}-ec2
aws cloudformation wait stack-delete-complete --stack-name ${PREFIX}-ec2
```

### 4.2 S3 (3 private buckets, versioning)

```bash
aws cloudformation create-stack \
  --stack-name ${PREFIX}-s3 \
  --template-body file://cfn-s3.yaml \
  --parameters ParameterKey=ProjectPrefix,ParameterValue=${PREFIX} \
               ParameterKey=EnableVersioning,ParameterValue=true \
  || echo "Stack may already exist"

aws cloudformation wait stack-create-complete --stack-name ${PREFIX}-s3 || true
aws cloudformation describe-stacks --stack-name ${PREFIX}-s3 --query "Stacks[0].Outputs" | tee ../submission/07_cfn_s3_outputs.json
```

### 4.3 EC2 (public IP output)

```bash
aws cloudformation create-stack \
  --stack-name ${PREFIX}-ec2 \
  --template-body file://cfn-ec2.yaml \
  --parameters ParameterKey=ProjectPrefix,ParameterValue=${PREFIX} \
               ParameterKey=AmiId,ParameterValue=${AMI} \
               ParameterKey=InstanceType,ParameterValue=t3.micro \
  || echo "Stack may already exist"

aws cloudformation wait stack-create-complete --stack-name ${PREFIX}-ec2 || true
aws cloudformation describe-stacks --stack-name ${PREFIX}-ec2 --query "Stacks[0].Outputs" | tee ../submission/08_cfn_ec2_outputs.json
```

### 4.4 RDS (Academy often requires **PublicAccess=false**)

```bash
aws cloudformation create-stack \
  --stack-name ${PREFIX}-rds \
  --template-body file://cfn-rds.yaml \
  --parameters ParameterKey=ProjectPrefix,ParameterValue=${PREFIX} \
               ParameterKey=DBName,ParameterValue=appdb \
               ParameterKey=MasterUsername,ParameterValue=adminuser \
               ParameterKey=MasterUserPassword,ParameterValue='ChangeMeStrong#123!' \
               ParameterKey=PublicAccess,ParameterValue=false \
  || echo "Stack may already exist"

aws cloudformation wait stack-create-complete --stack-name ${PREFIX}-rds || true
aws cloudformation describe-stacks --stack-name ${PREFIX}-rds --query "Stacks[0].Outputs" | tee ../submission/09_cfn_rds_outputs.json
```

If a stack fails/rolls back, capture reasons:

```bash
aws cloudformation describe-stack-events \
  --stack-name ${PREFIX}-rds \
  --query "StackEvents[?ResourceStatus=='CREATE_FAILED'].[Timestamp,LogicalResourceId,ResourceType,ResourceStatusReason]" \
  --output table | tee ../submission/10_cfn_rds_failures.txt
```

---

## 5) Screenshots checklist (for grading)

- **Terraform**
  - `terraform output`
  - `terraform state list`
- **S3**
  - CLI: PublicAccessBlock (all `true`), Versioning `Enabled`
  - Console: Buckets list with names; one bucket’s **Properties → Versioning: Enabled**
- **EC2**
  - Console: Instances list with **Public IPv4**
  - CLI table (from section 3.1)
- **RDS**
  - Console: DB page with **Status: available**, **Endpoint/Port**, **Public access: Not publicly accessible**
  - CLI table for RDS (Outputs in section 4.4)
- **CloudFormation**
  - Each stack’s **Outputs** tab (`${PREFIX}-s3`, `${PREFIX}-ec2`, `${PREFIX}-rds`)
- **Repo**
  - `tree -L 2`
  - 2–3 code screenshots: `provider.tf`, `vpc.tf`, `ec2.tf`, `rds.tf`, `s3.tf`, plus masked `terraform.tfvars`

---

## 6) Cleanup (to avoid charges)

```bash
# CloudFormation
aws cloudformation delete-stack --stack-name ${PREFIX}-s3
aws cloudformation delete-stack --stack-name ${PREFIX}-ec2
aws cloudformation delete-stack --stack-name ${PREFIX}-rds

# Terraform
cd /workspaces/prog8870-aws-iac/terraform
terraform destroy -auto-approve
```

---

## 7) Troubleshooting quick fixes

- **Unable to locate credentials**  
  `export AWS_PROFILE=academy && aws sts get-caller-identity`  
  Re-paste fresh Academy credentials if expired.

- **S3 GetObjectLockConfiguration AccessDenied** (Academy)  
  The repo’s `s3.tf` uses **AWS CLI via `null_resource`** to create/patch buckets, avoiding the ObjectLock call.

- **CFN Template format error**  
  Run `aws cloudformation validate-template --template-body file://<file>.yaml` or restore from Appendix A.

- **RDS public access blocked**  
  Use `PublicAccess=false` parameter in **cfn-rds.yaml**.

- **Terraform var duplicated**  
  Ensure each key appears only once in `terraform.tfvars`.

---

## Appendix A — CloudFormation templates (known-good)

> Use these to **restore** templates if yours were corrupted. Save each block into the matching file under `cloudformation/`.

### A.1 `cloudformation/cfn-s3.yaml`

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: Create 3 private S3 buckets with PublicAccessBlock and optional versioning.

Parameters:
  ProjectPrefix:
    Type: String
    Default: denishakbari-8901001
    AllowedPattern: '^[a-z0-9-]+$'
    Description: Lowercase, hyphenated prefix used in bucket names.
  EnableVersioning:
    Type: String
    Default: 'true'
    AllowedValues: ['true','false']
    Description: Enable versioning on all buckets (true/false).

Conditions:
  DoVersioning: !Equals [ !Ref EnableVersioning, 'true' ]

Resources:
  BucketA:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Join
        - "-"
        - - !Ref ProjectPrefix
          - s3a
          - !Select [2, !Split ["/", !Ref "AWS::StackId"]]
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        IgnorePublicAcls: true
        BlockPublicPolicy: true
        RestrictPublicBuckets: true
      VersioningConfiguration:
        Status: !If [ DoVersioning, Enabled, Suspended ]

  BucketB:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Join
        - "-"
        - - !Ref ProjectPrefix
          - s3b
          - !Select [2, !Split ["/", !Ref "AWS::StackId"]]
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        IgnorePublicAcls: true
        BlockPublicPolicy: true
        RestrictPublicBuckets: true
      VersioningConfiguration:
        Status: !If [ DoVersioning, Enabled, Suspended ]

  BucketC:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Join
        - "-"
        - - !Ref ProjectPrefix
          - s3c
          - !Select [2, !Split ["/", !Ref "AWS::StackId"]]
      PublicAccessBlockConfiguration:
        BlockPublicAcls: true
        IgnorePublicAcls: true
        BlockPublicPolicy: true
        RestrictPublicBuckets: true
      VersioningConfiguration:
        Status: !If [ DoVersioning, Enabled, Suspended ]

Outputs:
  BucketAName:
    Value: !Ref BucketA
  BucketBName:
    Value: !Ref BucketB
  BucketCName:
    Value: !Ref BucketC
```

### A.2 `cloudformation/cfn-ec2.yaml`

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: EC2 in a new VPC with IGW, route table, and public subnet. Outputs the public IP.

Parameters:
  ProjectPrefix:
    Type: String
    Default: denishakbari-8901001
    AllowedPattern: '^[a-z0-9-]+$'
    Description: Lowercase, hyphenated prefix used for names/tags.
  AmiId:
    Type: AWS::EC2::Image::Id
    Description: AMI ID to launch (e.g., Amazon Linux 2023).
  InstanceType:
    Type: String
    Default: t3.micro
    AllowedValues: [t2.micro, t3.micro, t3a.micro, t3.small]
    Description: Instance type.

Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.4.0.0/16
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags: [{ Key: Name, Value: !Sub '${ProjectPrefix}-vpc-cfn' }]

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags: [{ Key: Name, Value: !Sub '${ProjectPrefix}-igw-cfn' }]

  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  PublicSubnet:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.4.1.0/24
      MapPublicIpOnLaunch: true
      AvailabilityZone: !Select [0, !GetAZs ""]
      Tags: [{ Key: Name, Value: !Sub '${ProjectPrefix}-public-1a-cfn' }]

  RouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags: [{ Key: Name, Value: !Sub '${ProjectPrefix}-rtb-public-cfn' }]

  DefaultRoute:
    Type: AWS::EC2::Route
    DependsOn: AttachGateway
    Properties:
      RouteTableId: !Ref RouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  PublicRouteAssoc:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet
      RouteTableId: !Ref RouteTable

  Ec2Sg:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Allow SSH (22) - demo only
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0
      SecurityGroupEgress:
        - IpProtocol: -1
          FromPort: 0
          ToPort: 0
          CidrIp: 0.0.0.0/0
      Tags: [{ Key: Name, Value: !Sub '${ProjectPrefix}-ec2-ssh-cfn' }]

  Ec2Instance:
    Type: AWS::EC2::Instance
    Properties:
      ImageId: !Ref AmiId
      InstanceType: !Ref InstanceType
      SubnetId: !Ref PublicSubnet
      SecurityGroupIds: [ !Ref Ec2Sg ]
      Tags: [{ Key: Name, Value: !Sub '${ProjectPrefix}-ec2-cfn' }]

Outputs:
  Ec2PublicIp:
    Description: Public IP of the EC2 instance
    Value: !GetAtt Ec2Instance.PublicIp
  InstanceId:
    Description: EC2 Instance ID
    Value: !Ref Ec2Instance
```

### A.3 `cloudformation/cfn-rds.yaml`

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: Public RDS MySQL (demo only) with its own VPC, two subnets (2 AZs), SG on 3306.

Parameters:
  ProjectPrefix:
    Type: String
    Default: denishakbari-8901001
    AllowedPattern: '^[a-z0-9-]+$'
  DBName:
    Type: String
    Default: appdb
  MasterUsername:
    Type: String
    Default: adminuser
  MasterUserPassword:
    Type: String
    NoEcho: true
    MinLength: 8
  PublicAccess:
    Type: String
    Default: 'true'
    AllowedValues: ['true','false']
    Description: Set to 'true' for PubliclyAccessible, 'false' if org policy blocks it.

Conditions:
  MakePublic: !Equals [ !Ref PublicAccess, 'true' ]

Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.5.0.0/16
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags: [{ Key: Name, Value: !Sub '${ProjectPrefix}-vpc-cfn-rds' }]

  SubnetA:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.5.1.0/24
      AvailabilityZone: !Select [0, !GetAZs ""]
      Tags: [{ Key: Name, Value: !Sub '${ProjectPrefix}-db-subnet-a' }]

  SubnetB:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.5.2.0/24
      AvailabilityZone: !Select [1, !GetAZs ""]
      Tags: [{ Key: Name, Value: !Sub '${ProjectPrefix}-db-subnet-b' }]

  RDSSG:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Allow MySQL 3306 (demo only)
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 3306
          ToPort: 3306
          CidrIp: 0.0.0.0/0
      SecurityGroupEgress:
        - IpProtocol: -1
          FromPort: 0
          ToPort: 0
          CidrIp: 0.0.0.0/0
      Tags: [{ Key: Name, Value: !Sub '${ProjectPrefix}-rds-mysql-sg' }]

  DBSubnets:
    Type: AWS::RDS::DBSubnetGroup
    Properties:
      DBSubnetGroupDescription: Subnets for RDS
      SubnetIds: [ !Ref SubnetA, !Ref SubnetB ]

  MyDB:
    Type: AWS::RDS::DBInstance
    Properties:
      DBInstanceIdentifier: !Sub '${ProjectPrefix}-mysql-cfn'
      DBName: !Ref DBName
      Engine: mysql
      EngineVersion: "8.0"
      DBInstanceClass: db.t3.micro
      AllocatedStorage: 20
      MasterUsername: !Ref MasterUsername
      MasterUserPassword: !Ref MasterUserPassword
      VPCSecurityGroups: [ !Ref RDSSG ]
      DBSubnetGroupName: !Ref DBSubnets
      PubliclyAccessible: !If [ MakePublic, true, false ]
      DeletionProtection: false
      BackupRetentionPeriod: 0
      MultiAZ: false
      DeleteAutomatedBackups: true
    DeletionPolicy: Delete
    UpdateReplacePolicy: Delete

Outputs:
  DBIdentifier:
    Value: !Ref MyDB
  RDSEndpoint:
    Value: !GetAtt MyDB.Endpoint.Address
  RDSPort:
    Value: !GetAtt MyDB.Endpoint.Port
  PubliclyAccessible:
    Value: !If [ MakePublic, 'true', 'false' ]
```
