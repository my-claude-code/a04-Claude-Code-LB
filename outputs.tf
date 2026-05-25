output "app_url" {
  description = "Application URL"
  value       = "https://${azurerm_public_ip.agw.fqdn}"
}

output "mysql_public_ip" {
  description = "SSH into MySQL VM"
  value       = azurerm_public_ip.mysql.ip_address
}

output "ssh_mysql" {
  description = "SSH command for MySQL VM"
  value       = "ssh ivansto@${azurerm_public_ip.mysql.ip_address}"
}

output "ACTION_REQUIRED" {
  description = "Add this redirect URI to Azure AD app registration once"
  value       = "Go to Azure AD > App registrations > your app > Authentication > Redirect URIs and add: https://${azurerm_public_ip.agw.fqdn}/auth/callback"
}
