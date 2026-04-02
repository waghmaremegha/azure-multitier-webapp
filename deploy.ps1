param(
    [Parameter(Mandatory=$true)]
    [string]$AdminPublicIP,

    [string]$AdminUsername = "azureadmin",

    [Parameter(Mandatory=$true)]
    [SecureString]$AdminPassword
)

# ============================================================
# Azure Multi-Tier Web App - Full Deployment Script
# Author: Megha
# Description: Deploys a 3-tier architecture (Web/App/DB)
#              with VNet, Subnets, NSGs, and Windows Server 2025 VMs
# ============================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Azure Multi-Tier Web App Deployment"    -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ---- VARIABLES ----
$resourceGroup     = "rg-multitier-app"
$location          = "westeurope"

# Networking
$vnetName          = "vnet-multitier"
$vnetAddress       = "10.0.0.0/16"
$webSubnetName     = "snet-web"
$webSubnetAddress  = "10.0.1.0/24"
$appSubnetName     = "snet-app"
$appSubnetAddress  = "10.0.2.0/24"
$dbSubnetName      = "snet-db"
$dbSubnetAddress   = "10.0.3.0/24"

# NSGs
$webNsgName        = "nsg-web"
$appNsgName        = "nsg-app"
$dbNsgName         = "nsg-db"

# VMs
$vmSize            = "Standard_B2s"
$webVmName         = "vm-web-01"
$appVmName         = "vm-app-01"
$dbVmName          = "vm-db-01"
$webPipName        = "pip-web-01"

# VM Credentials
$credential = New-Object System.Management.Automation.PSCredential($AdminUsername, $AdminPassword)

# ============================================================
# PHASE 1: RESOURCE GROUP
# Why: A container for all resources. Delete this = delete everything.
# ============================================================
Write-Host "`n[1/8] Creating Resource Group..." -ForegroundColor Yellow
New-AzResourceGroup -Name $resourceGroup -Location $location -Force | Out-Null
Write-Host "  Resource Group '$resourceGroup' created" -ForegroundColor Green

# ============================================================
# PHASE 2: NETWORK SECURITY GROUPS
# Why: Firewalls that control who can talk to each subnet.
#      We create them BEFORE the VNet so we can attach them to subnets.
# ============================================================
Write-Host "`n[2/8] Creating Network Security Groups..." -ForegroundColor Yellow

# --- NSG: Web Tier ---
# Allows: HTTP/HTTPS from internet + RDP from admin IP only
$webRule1 = New-AzNetworkSecurityRuleConfig `
    -Name "Allow-HTTP-HTTPS" `
    -Priority 100 `
    -Direction Inbound `
    -Access Allow `
    -Protocol Tcp `
    -SourceAddressPrefix Internet `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 80,443

$webRule2 = New-AzNetworkSecurityRuleConfig `
    -Name "Allow-RDP-Admin" `
    -Priority 110 `
    -Direction Inbound `
    -Access Allow `
    -Protocol Tcp `
    -SourceAddressPrefix "$AdminPublicIP/32" `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 3389

$webNsg = New-AzNetworkSecurityGroup `
    -Name $webNsgName `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -SecurityRules $webRule1, $webRule2

Write-Host "  NSG '$webNsgName' created (HTTP/HTTPS + RDP)" -ForegroundColor Green

# --- NSG: App Tier ---
# Allows: Port 8080 from web subnet ONLY + RDP from admin IP
$appRule1 = New-AzNetworkSecurityRuleConfig `
    -Name "Allow-From-WebTier" `
    -Priority 100 `
    -Direction Inbound `
    -Access Allow `
    -Protocol Tcp `
    -SourceAddressPrefix $webSubnetAddress `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 8080

$appRule2 = New-AzNetworkSecurityRuleConfig `
    -Name "Allow-RDP-Admin" `
    -Priority 110 `
    -Direction Inbound `
    -Access Allow `
    -Protocol Tcp `
    -SourceAddressPrefix "$AdminPublicIP/32" `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 3389

$appNsg = New-AzNetworkSecurityGroup `
    -Name $appNsgName `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -SecurityRules $appRule1, $appRule2

Write-Host "  NSG '$appNsgName' created (Port 8080 from web subnet only)" -ForegroundColor Green

# --- NSG: DB Tier ---
# Allows: Port 1433 (SQL Server) from app subnet ONLY
# No RDP at all - most locked down tier
$dbRule1 = New-AzNetworkSecurityRuleConfig `
    -Name "Allow-SQL-From-AppTier" `
    -Priority 100 `
    -Direction Inbound `
    -Access Allow `
    -Protocol Tcp `
    -SourceAddressPrefix $appSubnetAddress `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 1433

$dbNsg = New-AzNetworkSecurityGroup `
    -Name $dbNsgName `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -SecurityRules $dbRule1

Write-Host "  NSG '$dbNsgName' created (SQL 1433 from app subnet only)" -ForegroundColor Green

# ============================================================
# PHASE 3: VIRTUAL NETWORK + SUBNETS
# Why: Our private network with 3 isolated rooms (subnets).
#      Each subnet gets its NSG attached during creation.
# ============================================================
Write-Host "`n[3/8] Creating Virtual Network and Subnets..." -ForegroundColor Yellow

$webSubnet = New-AzVirtualNetworkSubnetConfig `
    -Name $webSubnetName `
    -AddressPrefix $webSubnetAddress `
    -NetworkSecurityGroupId $webNsg.Id

$appSubnet = New-AzVirtualNetworkSubnetConfig `
    -Name $appSubnetName `
    -AddressPrefix $appSubnetAddress `
    -NetworkSecurityGroupId $appNsg.Id

$dbSubnet = New-AzVirtualNetworkSubnetConfig `
    -Name $dbSubnetName `
    -AddressPrefix $dbSubnetAddress `
    -NetworkSecurityGroupId $dbNsg.Id

$vnet = New-AzVirtualNetwork `
    -Name $vnetName `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -AddressPrefix $vnetAddress `
    -Subnet $webSubnet, $appSubnet, $dbSubnet

Write-Host "  VNet '$vnetName' created with 3 subnets (NSGs attached)" -ForegroundColor Green

# ============================================================
# PHASE 4: PUBLIC IP FOR WEB TIER
# Why: Only the web VM gets a public IP so users can reach it.
#      App and DB VMs stay completely private.
# ============================================================
Write-Host "`n[4/8] Creating Public IP for Web Tier..." -ForegroundColor Yellow

$webPip = New-AzPublicIpAddress `
    -Name $webPipName `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -AllocationMethod Static `
    -Sku Standard

Write-Host "  Public IP '$webPipName' created: $($webPip.IpAddress)" -ForegroundColor Green

# ============================================================
# PHASE 5: NETWORK INTERFACES (NICs)
# Why: A NIC connects a VM to a subnet. Each VM needs one.
#      Only the web NIC gets the public IP attached.
# ============================================================
Write-Host "`n[5/8] Creating Network Interfaces..." -ForegroundColor Yellow

# Refresh VNet to get subnet IDs
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroup

$webNic = New-AzNetworkInterface `
    -Name "$webVmName-nic" `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -SubnetId ($vnet.Subnets | Where-Object Name -eq $webSubnetName).Id `
    -PublicIpAddressId $webPip.Id

$appNic = New-AzNetworkInterface `
    -Name "$appVmName-nic" `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -SubnetId ($vnet.Subnets | Where-Object Name -eq $appSubnetName).Id

$dbNic = New-AzNetworkInterface `
    -Name "$dbVmName-nic" `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -SubnetId ($vnet.Subnets | Where-Object Name -eq $dbSubnetName).Id

Write-Host "  3 NICs created (web has public IP, app/db are private)" -ForegroundColor Green

# ============================================================
# PHASE 6: VIRTUAL MACHINES
# Why: The actual Windows Server 2025 computers in each tier.
# ============================================================
Write-Host "`n[6/8] Creating Virtual Machines (this takes 5-10 minutes)..." -ForegroundColor Yellow

# --- Web VM ---
$webVmConfig = New-AzVMConfig -VMName $webVmName -VMSize $vmSize
$webVmConfig = Set-AzVMOperatingSystem `
    -VM $webVmConfig `
    -Windows `
    -ComputerName $webVmName `
    -Credential $credential
$webVmConfig = Set-AzVMSourceImage `
    -VM $webVmConfig `
    -PublisherName "MicrosoftWindowsServer" `
    -Offer "WindowsServer" `
    -Skus "2025-datacenter-azure-edition" `
    -Version "latest"
$webVmConfig = Add-AzVMNetworkInterface -VM $webVmConfig -Id $webNic.Id

New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $webVmConfig | Out-Null
Write-Host "  VM '$webVmName' created (Web Tier)" -ForegroundColor Green

# --- App VM ---
$appVmConfig = New-AzVMConfig -VMName $appVmName -VMSize $vmSize
$appVmConfig = Set-AzVMOperatingSystem `
    -VM $appVmConfig `
    -Windows `
    -ComputerName $appVmName `
    -Credential $credential
$appVmConfig = Set-AzVMSourceImage `
    -VM $appVmConfig `
    -PublisherName "MicrosoftWindowsServer" `
    -Offer "WindowsServer" `
    -Skus "2025-datacenter-azure-edition" `
    -Version "latest"
$appVmConfig = Add-AzVMNetworkInterface -VM $appVmConfig -Id $appNic.Id

New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $appVmConfig | Out-Null
Write-Host "  VM '$appVmName' created (App Tier)" -ForegroundColor Green

# --- DB VM ---
$dbVmConfig = New-AzVMConfig -VMName $dbVmName -VMSize $vmSize
$dbVmConfig = Set-AzVMOperatingSystem `
    -VM $dbVmConfig `
    -Windows `
    -ComputerName $dbVmName `
    -Credential $credential
$dbVmConfig = Set-AzVMSourceImage `
    -VM $dbVmConfig `
    -PublisherName "MicrosoftWindowsServer" `
    -Offer "WindowsServer" `
    -Skus "2025-datacenter-azure-edition" `
    -Version "latest"
$dbVmConfig = Add-AzVMNetworkInterface -VM $dbVmConfig -Id $dbNic.Id

New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $dbVmConfig | Out-Null
Write-Host "  VM '$dbVmName' created (DB Tier)" -ForegroundColor Green

# ============================================================
# PHASE 7: INSTALL SOFTWARE USING CUSTOM SCRIPT EXTENSION
# Why: Automatically installs IIS, ASP.NET, SQL Server on VMs
#      without manually RDP-ing into each one.
# ============================================================
Write-Host "`n[7/8] Installing software on VMs..." -ForegroundColor Yellow

# Web VM: Install IIS + URL Rewrite for reverse proxy
$webScript = @'
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Install-WindowsFeature -Name Web-WebSockets
Install-WindowsFeature -Name Web-Request-Monitor

# Create a simple default page
$html = @"
<!DOCTYPE html>
<html>
<head><title>Web Tier - Multi-Tier App</title></head>
<body>
<h1>Welcome to the Multi-Tier Web App</h1>
<p>This is the <strong>Web Tier</strong> running on IIS.</p>
<p>Server: $env:COMPUTERNAME</p>
<p>Tier: Frontend (Reverse Proxy)</p>
</body>
</html>
"@
$html | Out-File -FilePath "C:\inetpub\wwwroot\index.html" -Encoding UTF8 -Force

New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
New-NetFirewallRule -DisplayName "Allow HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
'@

Set-AzVMExtension `
    -ResourceGroupName $resourceGroup `
    -VMName $webVmName `
    -Name "InstallWebServer" `
    -Publisher "Microsoft.Compute" `
    -ExtensionType "CustomScriptExtension" `
    -TypeHandlerVersion "1.10" `
    -SettingString "{`"commandToExecute`": `"powershell -ExecutionPolicy Unrestricted -Command $($webScript -replace '"','\"' -replace "`n","; ")`"}" | Out-Null

Write-Host "  IIS installed on '$webVmName'" -ForegroundColor Green

# App VM: Install IIS + ASP.NET
$appScript = @'
Install-WindowsFeature -Name Web-Server, Web-Asp-Net45 -IncludeManagementTools

$html = @"
<!DOCTYPE html>
<html>
<head><title>App Tier - Multi-Tier App</title></head>
<body>
<h1>App Tier Backend</h1>
<p>This is the <strong>App Tier</strong> running on IIS with ASP.NET.</p>
<p>Server: $env:COMPUTERNAME</p>
<p>Tier: Application Logic</p>
</body>
</html>
"@
$html | Out-File -FilePath "C:\inetpub\wwwroot\index.html" -Encoding UTF8 -Force

New-NetFirewallRule -DisplayName "Allow App Port" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
'@

Set-AzVMExtension `
    -ResourceGroupName $resourceGroup `
    -VMName $appVmName `
    -Name "InstallAppServer" `
    -Publisher "Microsoft.Compute" `
    -ExtensionType "CustomScriptExtension" `
    -TypeHandlerVersion "1.10" `
    -SettingString "{`"commandToExecute`": `"powershell -ExecutionPolicy Unrestricted -Command $($appScript -replace '"','\"' -replace "`n","; ")`"}" | Out-Null

Write-Host "  IIS + ASP.NET installed on '$appVmName'" -ForegroundColor Green

# DB VM: Configure SQL Server firewall rule
$dbScript = @'
New-NetFirewallRule -DisplayName "Allow SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow
'@

Set-AzVMExtension `
    -ResourceGroupName $resourceGroup `
    -VMName $dbVmName `
    -Name "ConfigureDBServer" `
    -Publisher "Microsoft.Compute" `
    -ExtensionType "CustomScriptExtension" `
    -TypeHandlerVersion "1.10" `
    -SettingString "{`"commandToExecute`": `"powershell -ExecutionPolicy Unrestricted -Command $($dbScript -replace '"','\"' -replace "`n","; ")`"}" | Out-Null

Write-Host "  SQL Server firewall configured on '$dbVmName'" -ForegroundColor Green

# ============================================================
# PHASE 8: DEPLOYMENT SUMMARY
# ============================================================
Write-Host "`n[8/8] Deployment Complete!" -ForegroundColor Yellow

$webPipRefresh = Get-AzPublicIpAddress -Name $webPipName -ResourceGroupName $resourceGroup

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " DEPLOYMENT SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Resource Group : $resourceGroup"
Write-Host "  Region         : $location"
Write-Host "  VNet           : $vnetName ($vnetAddress)"
Write-Host ""
Write-Host "  Web VM         : $webVmName"
Write-Host "    Public IP    : $($webPipRefresh.IpAddress)"
Write-Host "    Website      : http://$($webPipRefresh.IpAddress)"
Write-Host "    RDP          : mstsc /v:$($webPipRefresh.IpAddress)"
Write-Host ""
Write-Host "  App VM         : $appVmName (private - no public IP)"
Write-Host "  DB VM          : $dbVmName (private - no public IP)"
Write-Host ""
Write-Host "  Username       : $AdminUsername"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  To clean up all resources:" -ForegroundColor Red
Write-Host "  .\cleanup.ps1" -ForegroundColor Red
