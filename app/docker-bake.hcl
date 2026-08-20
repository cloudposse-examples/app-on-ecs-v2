variable "APP_IMAGE" {
  default = ""
}

target "app" {
  context    = "app"
  dockerfile = "Dockerfile"
  tags       = [APP_IMAGE]
}
