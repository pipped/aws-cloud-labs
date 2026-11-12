# SecureWeb VPC in Terraform

Rebuilds the network from [Lab 2](../../labs/02-secureweb-vpc.md) as code.

## Usage

```bash
terraform init
terraform plan  -var="admin_cidr=$(curl -s https://checkip.amazonaws.com)/32"
terraform apply -var="admin_cidr=$(curl -s https://checkip.amazonaws.com)/32"
```

Tear it down with `terraform destroy`. None of these resources cost anything on their own (no NAT gateway), but delete them anyway when you're done.

## What it creates
- `SecureWeb-vpc` (10.0.0.0/16) with DNS hostnames and resolution turned on
- 2 public subnets (10.0.0.0/20, 10.0.16.0/20) and 2 private subnets (10.0.128.0/20, 10.0.144.0/20)
- Internet gateway and public route table
- One private route table per AZ, with the S3 gateway endpoint attached
- A security group that allows HTTP, HTTPS and SSH only from `admin_cidr`
