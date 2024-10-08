variable "region" {
  description = "The AWS region to deploy resources in"
}

variable "bucket_name" {
  description = "The name of the S3 bucket"
}

provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "website_bucket" {
  bucket = var.bucket_name
  acl    = "public-read"
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })
}

variable "domain_name" {
  description = "The domain name to deploy the website in"
}

resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

resource "aws_route53_record" "website_record" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [aws_s3_bucket.website_bucket.website_endpoint]

  alias {
    name                   = aws_s3_bucket.website_bucket.website_domain
    zone_id                = aws_route53_zone.primary.zone_id
    evaluate_target_health = false
  }
}


// user
resource "aws_iam_user" "s3_user" {
  name = "s3-user"
}

resource "aws_iam_policy" "s3_policy" {
  name        = "s3-user-policy"
  description = "Policy for a user to access only specific S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = [
          "${aws_s3_bucket.website_bucket.arn}",
          "${aws_s3_bucket.website_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "attach_s3_policy" {
  user       = aws_iam_user.s3_user.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

