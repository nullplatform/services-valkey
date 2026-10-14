terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # Only for public caches: the aws provider cannot set a serverless cache's connection type yet.
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.105"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "awscc" {
  region = var.region
}
