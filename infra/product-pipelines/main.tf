provider "buildkite" {
  organization               = var.buildkite_organization_slug
  archive_pipeline_on_delete = true
}

locals {
  products = {
    llvm = {
      name = "LLVM Core"
      slug = "llvm-product-llvm-core"
    }
    clang = {
      name = "Clang"
      slug = "llvm-product-clang"
    }
    lld = {
      name = "LLD"
      slug = "llvm-product-lld"
    }
    runtimes = {
      name = "C++ Runtimes"
      slug = "llvm-product-cpp-runtimes"
    }
    mlir = {
      name = "MLIR"
      slug = "llvm-product-mlir"
    }
    flang = {
      name = "Flang"
      slug = "llvm-product-flang"
    }
    lldb = {
      name = "LLDB"
      slug = "llvm-product-lldb"
    }
    compiler-rt = {
      name = "compiler-rt"
      slug = "llvm-product-compiler-rt"
    }
    openmp = {
      name = "OpenMP"
      slug = "llvm-product-openmp"
    }
    bolt = {
      name = "BOLT"
      slug = "llvm-product-bolt"
    }
    polly = {
      name = "Polly"
      slug = "llvm-product-polly"
    }
  }
}

resource "buildkite_pipeline" "product" {
  for_each = local.products

  name            = "LLVM Product - ${each.value.name}"
  slug            = each.value.slug
  description     = "Demo-only ${each.value.name} release pipeline from the shared LLVM monorepo"
  repository      = var.buildkite_pipeline_repository
  default_branch  = var.buildkite_pipeline_default_branch
  cluster_id      = var.buildkite_hosted_cluster_graphql_id
  default_team_id = var.buildkite_default_team_graphql_id
  steps           = file("${path.module}/../../.buildkite/product-bootstrap.yml")
  tags            = ["llvm-demo", "monorepo-product"]

  provider_settings = {
    trigger_mode          = "none"
    build_branches        = false
    build_pull_requests   = false
    build_tags            = false
    publish_commit_status = false
  }
}
