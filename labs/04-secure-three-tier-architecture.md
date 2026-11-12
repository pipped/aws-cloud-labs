# Lab 4: Secure Three-Tier Architecture ("EvilBank")

**Date:** April 2025
**Scenario:** A fictional bank ("EvilBank") needs a production-style AWS environment with **defense in depth**: network isolation, tiered firewalls, strong identity, a web application firewall, backups, DNS and a private link back to the office.

## Architecture

```mermaid
flowchart TB
    Users((Customers)) --> R53["Route 53<br/>bank domain"]
    R53 --> WAF["AWS WAF<br/>web ACL 'EVILWAF' (regional)"]
    Office((On-prem office)) <--> VPN["Site-to-Site VPN 'VPN EVIL'<br/>Virtual private gateway, BGP"]

    subgraph VPC["project-vpc 10.0.0.0/16"]
        IGW[project-igw]
        NAT["NAT gateway<br/>(public subnet 1a)"]
        subgraph A["us-east-1a"]
            PA[public1] 
            RA[private1]
        end
        subgraph B["us-east-1b"]
            PB[public2]
            RB[private2]
        end
        subgraph C["us-east-1c"]
            PC[public3]
            RC[private3]
        end
        WEB["Web Tier SG"]
        APP["App Tier SG"]
        DB[("RDS MySQL<br/>db.t4g.micro")]
        S3EP[project-vpce-s3]
    end
    BK["AWS Backup<br/>Daily-35day-Retention"]

    WAF --> IGW --> PA & PB & PC
    PA & PB & PC --- WEB
    WEB --> APP --> DB
    RA & RB & RC --> NAT --> IGW
    RA & RB & RC --> S3EP
    VPN --- VPC
    BK -. snapshots .-> DB
```

## Step by step

### 1. VPC across three AZs
| Setting | Value |
|--------|-------|
| Name | `project` |
| CIDR | `10.0.0.0/16` |
| AZs | **3** (us-east-1a, 1b, 1c) |
| Subnets | 3 public + 3 private |
| Route tables | 1 public + 3 private |
| NAT gateway | 1 (in public subnet 1a) |
| Endpoint | S3 gateway |

The **NAT gateway** lets private instances reach the internet for patches without being reachable from it.

### 2. Tiered security groups
**Web Tier**: built for the internet-facing layer.

| Direction | Type | Port | Destination |
|-----------|------|------|-------------|
| Outbound | All traffic | All | 0.0.0.0/0 |
| Outbound | HTTP | 80 | 0.0.0.0/0 |
| Outbound | HTTPS | 443 | 0.0.0.0/0 |

**App Tier**: only talks to the tier it's chained to.

| Direction | Type | Port | Destination |
|-----------|------|------|-------------|
| Outbound | All traffic | All | 0.0.0.0/0 |
| Outbound | Custom TCP | — | **Another security group (by SG ID)** |

Referencing a **security group ID** instead of a CIDR means the rule follows the instances as they scale, with no IP lists to keep updated.

### 3. IAM & MFA
- Reviewed the service-linked roles AWS created for **Elastic Load Balancing** and **RDS**.
- Registered an MFA device with the **passkey/security key** option (FIDO2), the most phishing-resistant choice.

### 4. AWS WAF
- Created a regional web ACL **`EVILWAF`** in us-east-1, with CloudWatch metrics under the same name, to attach to the load balancer and filter SQL injection, XSS and bad bots before they reach the app.

### 5. RDS
- Created a MySQL instance on **db.t4g.micro** (burstable class) with a self-managed admin password. Next time I'd let **AWS Secrets Manager** manage and rotate it.

### 6. Route 53
- Looked up domain availability for the bank's domain in **Route 53 → Register domains** to give the app a public DNS name.

### 7. AWS Backup
- Backup plan **`EVIL DBUA`** from the **Daily-35day-Retention** template, with rule `DailyBackups` going to the default vault.

### 8. Site-to-Site VPN
| Setting | Value |
|---------|-------|
| Name | `VPN EVIL` |
| Target gateway | Virtual private gateway |
| Customer gateway | Existing |
| Routing | **Dynamic (BGP)** |
| Local IPv4 CIDR | `10.0.0.0/16` |
| Remote IPv4 CIDR | `0.0.0.0/0` |

This gives the office an encrypted IPsec tunnel into the VPC, so admin traffic never goes over the public internet.

## Security layers at a glance

| Layer | Control |
|-------|---------|
| Edge | Route 53, AWS WAF |
| Network | Public/private subnets, NAT, S3 endpoint, VPN |
| Instance | Web/App tier security groups chained by SG ID |
| Identity | IAM, FIDO2 MFA |
| Data | RDS in private subnets, AWS Backup with 35-day retention |

## What I learned
- How **defense in depth** looks on AWS: each layer assumes the one in front of it might fail.
- Chaining security groups is cleaner and safer than hard-coding IP ranges.
- Spreading across **three AZs** with a single NAT gateway is a cost trade-off. In production, use one NAT per AZ so losing an AZ doesn't cut off outbound traffic.
- Backups are only useful if you **test the restores**, which is the next step for this lab.

## Screenshots

**3-AZ VPC with NAT gateway and S3 endpoint**
![VPC](../images/l4-vpc.png)

| | |
|---|---|
| **Web Tier security group**<br>![Web SG](../images/l4-web-sg.png) | **App Tier security group (references another SG)**<br>![App SG](../images/l4-app-sg.png) |
| **Service-linked roles for ELB and RDS**<br>![IAM roles](../images/l4-iam-roles.png) | **MFA with a passkey/security key**<br>![MFA](../images/l4-mfa.png) |
| **WAF web ACL `EVILWAF`**<br>![WAF](../images/l4-waf.png) | **RDS MySQL settings**<br>![RDS](../images/l4-rds.png) |
| **Route 53 domain search**<br>![Route 53](../images/l4-route53.png) | **AWS Backup plan (35-day retention)**<br>![Backup](../images/l4-backup.png) |
| **Site-to-Site VPN (BGP)**<br>![VPN](../images/l4-vpn.png) | |
