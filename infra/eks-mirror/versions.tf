terraform {
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.52.0, < 7.0.0"
    }

    buildkite = {
      source  = "buildkite/buildkite"
      version = "~> 1.35.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "= 3.1.1"
    }
  }
}
