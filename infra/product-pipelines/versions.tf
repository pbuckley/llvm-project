terraform {
  required_version = ">= 1.11.0"

  required_providers {
    buildkite = {
      source  = "buildkite/buildkite"
      version = "~> 1.35"
    }
  }
}
