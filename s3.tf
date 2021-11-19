resource "aws_s3_bucket" "mbta-lb-access-logs" {
  acl           = "private"
  bucket        = "mbta-lb-access-logs"
  force_destroy = true

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
     {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::${var.log-bucket-owner-id}:root"
        },
        "Action": "s3:PutObject",
        "Resource": "arn:aws:s3:::mbta-lb-access-logs/*"
      },
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "delivery.logs.amazonaws.com"
        },
        "Action": "s3:PutObject",
        "Resource": "arn:aws:s3:::mbta-lb-access-logs/*",
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
        "Resource": "arn:aws:s3:::mbta-lb-access-logs"
      }
    ]
}
POLICY
  
  tags = {
    project     = "MBTA-Keycloak"
    Name        = "Keycloak-LB-Logs"
  }
}

