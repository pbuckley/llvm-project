# LLVM product pipelines

This small Terraform root creates 11 private Buildkite pipelines that all read
the same LLVM monorepo. The parent pipeline uses the monorepo-diff plugin to
trigger only the products whose folders changed, preserving an independent
pipeline history for every product.

The product pipeline definition is shared in
`.buildkite/product-pipeline.yml`; the component name and immutable commit are
passed by the parent trigger step. GitHub activity does not start these child
pipelines directly (`trigger_mode = "none"`).

```bash
cd infra/product-pipelines
terraform init
export BUILDKITE_API_TOKEN="$(bk auth token)"
terraform apply
```

The live pipelines were initially bootstrapped through the REST API. The
checked-in `import` blocks adopt those exact pipeline IDs on the first
Terraform run. The token requires Buildkite GraphQL access plus
`read_pipelines` and `write_pipelines`; the ordinary `bk` token used during
setup lacked GraphQL scope. Terraform state is local and ignored for this demo.
