run "applies_ecs_service_against_emulator" {
  command = apply

  assert {
    condition     = output.ecs_service_name != ""
    error_message = "Expected the ECS service to be created."
  }

  assert {
    condition     = output.ecs_service_cluster != ""
    error_message = "Expected the ECS service to reference a cluster."
  }

  assert {
    condition     = output.task_definition_arn != ""
    error_message = "Expected the task definition to be registered."
  }

  assert {
    condition     = output.url == "http://cplive-plat-ue2-fixtures-app.local.test/dashboard"
    error_message = "Expected the fixture URL to use the rendered service hostname."
  }
}
