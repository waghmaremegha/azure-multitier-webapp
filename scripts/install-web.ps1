# ============================================================
# Web Tier - IIS Installation Script
# Runs on: vm-web-01
# Purpose: Install IIS as a reverse proxy that forwards
#          traffic to the App Tier (10.0.2.x:8080)
# ============================================================

# Install IIS with management tools
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature -Name Web-WebSockets
Install-WindowsFeature -Name Web-Request-Monitor

# Create a default landing page
$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Web Tier - Azure Multi-Tier App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f0f4f8; }
        .container { background: white; padding: 30px; border-radius: 8px; max-width: 600px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #0F6E56; }
        .tier { background: #E1F5EE; padding: 10px 15px; border-radius: 4px; display: inline-block; }
        .info { color: #666; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Azure Multi-Tier Web App</h1>
        <div class="tier">Web Tier - Frontend</div>
        <p>This is the <strong>Web Tier</strong> running on IIS (Windows Server 2025).</p>
        <p>This server acts as a reverse proxy, forwarding requests to the App Tier.</p>
        <div class="info">
            <p><strong>Server:</strong> $env:COMPUTERNAME</p>
            <p><strong>Role:</strong> IIS Reverse Proxy</p>
            <p><strong>Subnet:</strong> snet-web (10.0.1.0/24)</p>
        </div>
    </div>
</body>
</html>
"@
$html | Out-File -FilePath "C:\inetpub\wwwroot\index.html" -Encoding UTF8 -Force

# Open firewall ports
New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
New-NetFirewallRule -DisplayName "Allow HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow

Write-Host "Web Tier setup complete. IIS is running." -ForegroundColor Green
