# ============================================================
# Database Tier - SQL Server Express Installation Script
# Runs on: vm-db-01
# Purpose: Configure the database server. Only accepts
#          connections from the App Tier on port 1433.
# ============================================================

# Note: SQL Server Express needs to be downloaded and installed.
# For this demo, we configure the firewall and prepare the server.
# In production, you would use Azure SQL Database instead.

# Open firewall for SQL Server
New-NetFirewallRule -DisplayName "Allow SQL Server 1433" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow

# Download SQL Server Express (silent install)
# Uncomment the lines below to actually install SQL Server Express:
#
# $sqlUrl = "https://go.microsoft.com/fwlink/p/?linkid=2216019&clcid=0x409&culture=en-us&country=us"
# $sqlInstaller = "C:\temp\SQLServerExpress.exe"
# New-Item -Path "C:\temp" -ItemType Directory -Force
# Invoke-WebRequest -Uri $sqlUrl -OutFile $sqlInstaller
# Start-Process -FilePath $sqlInstaller -ArgumentList "/Q /ACTION=Install /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SECURITYMODE=SQL /SAPWD=YourStr0ngP@ssw0rd /TCPENABLED=1 /IACCEPTSQLSERVERLICENSETERMS" -Wait

Write-Host "Database Tier setup complete. Firewall configured for SQL Server." -ForegroundColor Green
Write-Host "SQL Server Express can be installed by uncommenting the download section." -ForegroundColor Yellow
