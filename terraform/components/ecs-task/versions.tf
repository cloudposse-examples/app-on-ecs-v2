terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      ## 4.66.0 version cause error
      ## │ Error: listing tags for Application Auto Scaling Target (): InvalidParameter: 1 validation error(s) found.
      ## │ - minimum field size of 1, ListTagsForResourceInput.ResourceARN.
      ## │
      ## │
      ## │   with module.ecs_cloudwatch_autoscaling[0].aws_appautoscaling_target.default[0],
      ## │   on .terraform/modules/ecs_cloudwatch_autoscaling/main.tf line 15, in resource "aws_appautoscaling_target" "default":
      ## │   15: resource "aws_appautoscaling_target" "default" {
      # 6.58.0 fixes aws_ecs_service sigint_rollback falsely rolling back
      # healthy deployments while wait_for_steady_state is enabled.
      version = ">= 6.58.0"
    }
    template = {
      source  = "cloudposse/template"
      version = ">= 2.2"
    }
    jq = {
      source  = "massdriver-cloud/jq"
      version = ">=0.2.0"
    }
    utils = {
      source  = "cloudposse/utils"
      version = ">= 2.3.0"
    }
  }
}
