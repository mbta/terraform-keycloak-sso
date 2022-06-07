resource "aws_s3_bucket" "keycloak-lb-access-logs" {
  # only create this resource if lb_access_logs_s3_bucket is null
  count = var.lb_access_logs_s3_bucket == null ? 1 : 0

  acl           = "private"
  bucket        = "${lower(var.organization)}-keycloak-${var.environment}-lb-access-logs"
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_policy" "keycloak-lb-access-logs" {
  # only create this resource if lb_access_logs_s3_bucket is null
  count = var.lb_access_logs_s3_bucket == null ? 1 : 0
  
  bucket = aws_s3_bucket.keycloak-lb-access-logs.id

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
