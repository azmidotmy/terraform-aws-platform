terraform {
  # mock_provider in terraform test arrived in Terraform 1.7
  # (Terraform changelog v1.7: "Providers, modules, resources, and data sources can now be mocked")
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
