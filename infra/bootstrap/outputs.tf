output "tfstate_bucket" {
  description = "Bucket que guarda o state das demais stacks."
  value       = aws_s3_bucket.tfstate.bucket
}
