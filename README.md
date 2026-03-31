# Azure Multi-Tier Web Application Deployment

A production-style 3-tier web application deployed on Microsoft Azure with enterprise networking, defense-in-depth security, and full PowerShell automation.

## Architecture

![Architecture Diagram](diagrams/architecture.png)

## What This Project Demonstrates

- **Virtual Network design** with proper address space planning (10.0.0.0/16)
- **Subnet segmentation** — each tier isolated in its own subnet
- **Network Security Groups (NSGs)** with least-privilege inbound rules
- **Defense in depth** — traffic flows strictly Web → App → DB; database has zero internet exposure
- **Jump box pattern** — RDP access to private VMs via the web tier
- **PowerShell automation** — entire infrastructure deployed with a single script
- **Custom Script Extensions** — automated software installation on VMs post-deployment

## Technology Stack

| Component | Technology |
|-----------|-----------|
| OS | Windows Server 2025 Datacenter |
| Web Server | IIS with URL Rewrite + ARR (Reverse Proxy) |
| App Runtime | IIS + ASP.NET |
| Database | SQL Server Express |
| VM Size | Standard_B2s (2 vCPU, 4 GB RAM) |
| Automation | Azure PowerShell (Az Module) |
| Region | West Europe |

## Network Security Rules

### Web Tier (nsg-web)
| Priority | Rule | Source | Port | Purpose |
|----------|------|--------|------|---------|
| 100 | Allow HTTP/HTTPS | Internet | 80, 443 | Public web access |
| 110 | Allow RDP | Admin IP | 3389 | Management access |

### App Tier (nsg-app)
| Priority | Rule | Source | Port | Purpose |
|----------|------|--------|------|---------|
| 100 | Allow from Web | 10.0.1.0/24 | 8080 | Web-to-App communication |
| 110 | Allow RDP | Admin IP | 3389 | Management access |

### Database Tier (nsg-db)
| Priority | Rule | Source | Port | Purpose |
|----------|------|--------|------|---------|
| 100 | Allow SQL | 10.0.2.0/24 | 1433 | App-to-DB communication |

All other inbound traffic is denied by default.

## Project Structure

```
azure-multitier-webapp/
├── README.md                    # This file
├── deploy.ps1                   # Main deployment script
├── cleanup.ps1                  # Tear down all resources
├── scripts/
│   ├── install-web.ps1         # IIS + reverse proxy configuration
│   ├── install-app.ps1         # IIS + ASP.NET setup
│   └── install-db.ps1          # SQL Server Express installation
├── app/
│   └── default.aspx            # Demo web application
└── diagrams/
    └── architecture.png        # Architecture diagram
```

## Quick Start

### Prerequisites
- Azure subscription
- PowerShell 7+ with Az module installed
- Your public IP address (for RDP access)

### Deploy
```powershell
# Install Azure PowerShell module (one-time)
Install-Module -Name Az -Force -AllowClobber

# Login to Azure
Connect-AzAccount

# Run the deployment (replace with your public IP)
.\deploy.ps1 -AdminPublicIP "YOUR_PUBLIC_IP"
```

### Clean Up
```powershell
# Delete everything to avoid charges
.\cleanup.ps1
```

## Key Design Decisions

1. **No public IP on App/DB tiers** — reduces attack surface; only the web server faces the internet
2. **NSG per subnet (not per NIC)** — easier to manage and scales when adding more VMs to a tier
3. **SQL Server Express** — free edition, suitable for demo; production would use Azure SQL or SQL Server Standard
4. **B2s VM size** — minimum viable for Windows Server; keeps costs low for demonstration
5. **Single VNet** — all tiers communicate over private IPs with no internet hops

## Relevant Certifications

This project covers skills tested in:
- **AZ-104**: Microsoft Azure Administrator
  - Configure virtual networks and subnets
  - Implement and manage network security groups
  - Deploy and manage Azure compute resources
  - Automate deployment using PowerShell

## Author

**Megha** — Cloud Infrastructure & Azure Administration

## License

MIT
