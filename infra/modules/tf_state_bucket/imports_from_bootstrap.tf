import {
  to = aws_s3_bucket.this
  id = var.bucket_name
}

import {
  to = aws_s3_bucket_versioning.this
  id = var.bucket_name
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.this
  id = var.bucket_name
}

import {
  to = aws_s3_bucket_public_access_block.this
  id = var.bucket_name
}

import {
  to = aws_s3_bucket_ownership_controls.this
  id = var.bucket_name
}

import {
  to = aws_s3_bucket_policy.this
  id = var.bucket_name
}
