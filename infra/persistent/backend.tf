terraform {
  backend "s3" {
    bucket       = "solidarytech-tfstate-376903139600"
    key          = "persistent/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
