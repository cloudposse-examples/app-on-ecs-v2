output "url" {
  value       = format("http://%s%s", local.hostname, var.url_path)
  description = "The URL of the service"
} 