output "bucket_name" {
  description = "S3 bucket for remote state"
  value       = aws_s3_bucket.tfstate.bucket
}

