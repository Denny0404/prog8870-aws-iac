# S3 via CLI to avoid Academy deny on GetObjectLockConfiguration
resource "random_id" "suffix" { byte_length = 2 }

locals {
  s3_buckets = {
    data      = "${var.project_prefix}-data-${random_id.suffix.hex}"
    logs      = "${var.project_prefix}-logs-${random_id.suffix.hex}"
    artifacts = "${var.project_prefix}-artifacts-${random_id.suffix.hex}"
    assets    = "${var.project_prefix}-assets-${random_id.suffix.hex}"
  }
}

resource "null_resource" "s3" {
  for_each = local.s3_buckets

  triggers = {
    bucket     = each.value
    region     = var.region
    versioning = tostring(var.enable_s3_versioning)
  }

  # CREATE
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
set -e
BUCKET="${self.triggers.bucket}"
REGION="${self.triggers.region}"
VER="${self.triggers.versioning}"

# Create bucket (special-case us-east-1)
if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  echo "Bucket $BUCKET already exists"
else
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET"
  else
    aws s3api create-bucket --bucket "$BUCKET" --create-bucket-configuration LocationConstraint="$REGION"
  fi
fi

# Block public access
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Versioning
if [ "$VER" = "true" ]; then
  aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
else
  aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Suspended
fi
EOT
  }

  # DESTROY
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = <<EOT
set -e
BUCKET="${self.triggers.bucket}"
aws s3 rm "s3://$BUCKET" --recursive || true
aws s3api delete-bucket --bucket "$BUCKET" || true
EOT
  }
}

output "s3_bucket_names" { value = sort([for _, v in local.s3_buckets : v]) }
