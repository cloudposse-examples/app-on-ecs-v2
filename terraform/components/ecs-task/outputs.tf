output "url" {
  value       = format("http://%s%s", var.url_path)
  description = "The URL of the service"
} 