# Create 4 private S3 buckets with public access blocked
# Names must be globally unique; we add a short random suffix.
resource "random_id" "suffix" {
  byte_length = 2
}

locals {
  s3_bucket_names = [
    "${var.project_prefix}-data-${random_id.suffix.hex}",
    "${var.project_prefix}-logs-${random_id.suffix.hex}",
    "${var.project_prefix}-artifacts-${random_id.suffix.hex}",
    "${var.project_prefix}-assets-${random_id.suffix.hex}",
  ]
}

resource "aws_s3_bucket" "buckets" {
  for_each = toset(local.s3_bucket_names)
  bucket   = each.key
}

resource "aws_s3_bucket_ownership_controls" "own" {
  for_each = aws_s3_bucket.buckets
  bucket   = each.value.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "block" {
  for_each = aws_s3_bucket.buckets
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "versioning" {
  for_each = aws_s3_bucket.buckets
  bucket   = each.value.id
  versioning_configuration {
    status = var.enable_s3_versioning ? "Enabled" : "Suspended"
  }
}

output "s3_bucket_names" {
  value = local.s3_bucket_names
}
