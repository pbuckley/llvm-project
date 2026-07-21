output "product_pipelines" {
  description = "Product pipeline slugs and GraphQL IDs."
  value = {
    for product, pipeline in buildkite_pipeline.product : product => {
      id   = pipeline.id
      slug = pipeline.slug
    }
  }
}
