# Stack: virtual account "nonprod", layer "baseline".
# State key layout: <layer>/<stack>/terraform.tfstate (docs/01, section 1.2).

terraform {
  required_version = ">= 1.11.0" # use_lockfile: added in Terraform 1.10, generally available in 1.11 (changelog v1.10, v1.11)

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend arguments: Terraform Docs, "Backend Type: s3"
  # (https://developer.hashicorp.com/terraform/language/backend/s3).
  # Bucket and role values are placeholders replaced at deployment.
  backend "s3" {
    bucket       = "example-nonprod-tfstate-111122223333-ap-southeast-5"
    key          = "baseline/state-bucket/terraform.tfstate"
    region       = "ap-southeast-5"
    encrypt      = true
    kms_key_id   = "arn:aws:kms:ap-southeast-5:111122223333:key/11111111-2222-3333-4444-555555555555"
    use_lockfile = true

    # Optional separate state role (placeholder). docs/01, 1.3: no module creates it.
    assume_role = {
      role_arn = "arn:aws:iam::111122223333:role/nonprod-baseline-state"
    }
  }
}

provider "aws" {
  region = "ap-southeast-5"
}

module "state_bucket" {
  source = "../../../modules/secure-state-bucket"

  bucket_name = "example-nonprod-tfstate-111122223333-ap-southeast-5"
  kms_key_arn = "arn:aws:kms:ap-southeast-5:111122223333:key/11111111-2222-3333-4444-555555555555"

  tags = {
    VirtualAccount = "nonprod"
    Layer          = "baseline"
    Owner          = "central-platform"
  }
}
