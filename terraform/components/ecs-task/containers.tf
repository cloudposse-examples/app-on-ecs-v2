locals {
  container_definitions_json = jsonencode([
    for container_name, container_definition in local.container_definitions :
      merge(container_definition, { name : container_name })
  ])
  
  container_definitions = jsondecode(data.utils_deep_merge_json.example.output)

  override_containers_definitions = {
    # Uncomment and update code to override the container definitions fields:
    # app = {
    #   healthCheck = {
    #     command = ["CMD-SHELL", "curl -f http://localhost:8080/healthz || exit 1"]
    #   }
    # }
  }
}

data "utils_deep_merge_json" "example" {
  input = [
    jsonencode(var.containers),
    jsonencode(local.override_containers_definitions)
  ]
}