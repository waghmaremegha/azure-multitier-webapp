# ============================================================
# App Tier - IIS + ASP.NET Installation Script
# Runs on: vm-app-01
# Purpose: Install IIS with ASP.NET to run the application
#          logic. Only accepts traffic from Web Tier.
# ============================================================

# Install IIS with ASP.NET 4.5 support
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature -Name Web-Asp-Net45

# Create a simple app page
$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>App Tier - Azure Multi-Tier App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f0f0fa; }
        .container { background: white; padding: 30px; border-radius: 8px; max-width: 600px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #534AB7; }
        .tier { background: #EEEDFE; padding: 10px 15px; border-radius: 4px; display: inline-block; }
        .info { color: #666; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>App Tier - Backend</h1>
        <div class="tier">App Tier - Application Logic</div>
        <p>This is the <strong>App Tier</strong> running IIS with ASP.NET.</p>
        <p>This server processes business logic and connects to the Database Tier.</p>
        <div class="info">
            <p><strong>Server:</strong> $env:COMPUTERNAME</p>
            <p><strong>Role:</strong> IIS + ASP.NET Application Server</p>
            <p><strong>Subnet:</strong> snet-app (10.0.2.0/24)</p>
            <p><strong>Accepts from:</strong> Web Tier only (10.0.1.0/24)</p>
        </div>
    </div>
</body>
</html>
"@
$html | Out-File -FilePath "C:\inetpub\wwwroot\index.html" -Encoding UTF8 -Force

# Open firewall for app port
New-NetFirewallRule -DisplayName "Allow App Port 8080" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow

Write-Host "App Tier setup complete. IIS + ASP.NET is running." -ForegroundColor Green
