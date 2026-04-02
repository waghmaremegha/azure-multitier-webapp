# ============================================================
# Azure Multi-Tier Web App - Cleanup Script
# Author: Megha
# Description: Deletes the entire resource group and all resources
#              to avoid any ongoing Azure charges.
# ============================================================

$resourceGroup = "rg-multitier-app"

Write-Host "========================================" -ForegroundColor Red
Write-Host " WARNING: This will DELETE everything!" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Red
Write-Host ""
Write-Host "Resource Group: $resourceGroup"
Write-Host "This includes: VNet, Subnets, NSGs, VMs, Disks, NICs, Public IPs"
Write-Host ""

$confirm = Read-Host "Type 'yes' to confirm deletion"

if ($confirm -eq "yes") {
    Write-Host "`nDeleting resource group '$resourceGroup'..." -ForegroundColor Yellow
    Write-Host "This may take 2-5 minutes..." -ForegroundColor Yellow
    Remove-AzResourceGroup -Name $resourceGroup -Force
    Write-Host "`nAll resources deleted. No more charges." -ForegroundColor Green
} else {
    Write-Host "`nCancelled. Nothing was deleted." -ForegroundColor Cyan
}
