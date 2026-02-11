resource "aws_s3_bucket" "keycloak-lb-access-logs" {
  # only create this resource if lb_enable_access_logs is true and lb_access_logs_s3_bucket is null
  count = var.lb_enable_access_logs == true && var.lb_access_logs_s3_bucket == null ? 1 : 0

  bucket        = "${lower(var.organization)}-keycloak-${var.environment}-lb-access-logs"
  force_destroy = true

  # checkov:skip=CKV2_AWS_61:not bothering with lifecycle rules TODO
  # checkov:skip=CKV2_AWS_62:don't need event notifications
  # checkov:skip=CKV2_AWS_6:public access block configured below
  # checkov:skip=CKV_AWS_144:don't need cross-region replication
  # checkov:skip=CKV_AWS_145:encryption configured below
  # checkov:skip=CKV_AWS_18:don't need access logs
  # checkov:skip=CKV_AWS_21:don't need versioning
  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "keycloak-lb-access-logs" {
  count  = length(aws_s3_bucket.keycloak-lb-access-logs)
  bucket = aws_s3_bucket.keycloak-lb-access-logs[count.index].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "keycloak-lb-access-logs" {
  count  = length(aws_s3_bucket.keycloak-lb-access-logs)
  bucket = aws_s3_bucket.keycloak-lb-access-logs[count.index].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_acl" "keycloak-lb-access-logs" {
  # only create this resource if lb_enable_access_logs is true and lb_access_logs_s3_bucket is null
  count = var.lb_enable_access_logs == true && var.lb_access_logs_s3_bucket == null ? 1 : 0

  bucket = aws_s3_bucket.keycloak-lb-access-logs[0].id
  acl    = "private"
}

resource "aws_s3_bucket_policy" "keycloak-lb-access-logs" {
  # only create this resource if lb_enable_access_logs is true and lb_access_logs_s3_bucket is null
  count = var.lb_enable_access_logs == true && var.lb_access_logs_s3_bucket == null ? 1 : 0

  bucket = aws_s3_bucket.keycloak-lb-access-logs[0].id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
     {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action": "s3:PutObject",
        "Resource": "arn:aws:s3:::${lower(var.organization)}-keycloak-${var.environment}-lb-access-logs/*"
      },
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "delivery.logs.amazonaws.com"
        },
        "Action": "s3:PutObject",
        "Resource": "arn:aws:s3:::${lower(var.organization)}-keycloak-${var.environment}-lb-access-logs/*",
        "Condition": {
          "StringEquals": {
            "s3:x-amz-acl": "bucket-owner-full-control"
          }
        }
      },
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "delivery.logs.amazonaws.com"
        },
        "Action": "s3:GetBucketAcl",
        "Resource": "arn:aws:s3:::${lower(var.organization)}-keycloak-${var.environment}-lb-access-logs"
      }
    ]
}
POLICY
}
