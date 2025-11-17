output "url" {
  value       = format("http://%s", local.hostname)
  description = "The URL of the service"
} 