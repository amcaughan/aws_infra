module "bucket" {
  source = "../secure-s3-bucket"

  bucket_name = var.bucket_name
  force_destroy = false

  noncurrent_version_expiration_days = var.noncurrent_version_expiration_days
  abort_incomplete_multipart_days    = var.abort_incomplete_multipart_days

  enable_versioning = true
  enable_tls_deny   = true
}

# Re-expose resources for import compatibility
resource "aws_s3_bucket" "this" {
  bucket = module.bucket.bucket_name
}