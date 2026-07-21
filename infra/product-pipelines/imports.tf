# The live demo pipelines were bootstrapped through the Buildkite REST API so
# they could be used immediately with the operator's existing token. A token
# with GraphQL, read_pipelines, and write_pipelines scopes will adopt them into
# Terraform state on the first plan/apply.

import {
  to = buildkite_pipeline.product["bolt"]
  id = "UGlwZWxpbmUtLS0wMTlmODJmNC1jNDNkLTQ5YjEtYTE3NS01N2E0MDI0YTE0YzI="
}

import {
  to = buildkite_pipeline.product["clang"]
  id = "UGlwZWxpbmUtLS0wMTlmODJmNC0wYjk3LTQzMjYtYjk2MC1mOGQ4ZTAxZDI1ZjI="
}

import {
  to = buildkite_pipeline.product["compiler-rt"]
  id = "UGlwZWxpbmUtLS0wMTlmODJmNC1iNTQyLTRlZjEtYWRmMi02NmU2Mzg1N2RjYTA="
}

import {
  to = buildkite_pipeline.product["flang"]
  id = "UGlwZWxpbmUtLS0wMTlmODJmNC1hNjk3LTQ5YjMtOTdiMC0wZmM4MzRmYWYwMzQ="
}

import {
  to = buildkite_pipeline.product["lld"]
  id = "UGlwZWxpbmUtLS0wMTlmODJmNC05MjU5LTRiYmItYTM1OS1kNDM0MTYzMzM5MTc="
}

import {
  to = buildkite_pipeline.product["lldb"]
  id = "UGlwZWxpbmUtLS0wMTlmODJmNC1hZGNhLTQwMDQtOGRlNi0zMjdiNmZhNjc1MWE="
}

import {
  to = buildkite_pipeline.product["llvm"]
  id = "UGlwZWxpbmUtLS0wMTlmODJmNC04OWY2LTQ4ZjMtODJhYy1jNjE0ODY1M2MxMzY="
}

import {
  to = buildkite_pipeline.product["mlir"]
  id = "UGlwZWxpbmUtLS0wMTlmODJmNC1hMDAzLTRhNzktOWVlMi1iMjZmNzJhZjY5N2I="
}

import {
  to = buildkite_pipeline.product["openmp"]
  id = "UGlwZWxpbmUtLS0wMTlmODJmNC1iZDAxLTQ4MzgtODBiOC0yNWEwOWI3NjcwNTQ="
}

import {
  to = buildkite_pipeline.product["polly"]
  id = "UGlwZWxpbmUtLS0wMTlmODJmNC1jYjE3LTQzYTktODFjMy04NmMyYzBmZjhjYzQ="
}

import {
  to = buildkite_pipeline.product["runtimes"]
  id = "UGlwZWxpbmUtLS0wMTlmODJmNC05OGQwLTRkNDUtOGNlNC1iYzkyMWU4OWRlNzg="
}
