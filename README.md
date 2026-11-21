## Day 4 — AWS network verification

Terraform provisioned a VPC and four subnets across `us-west-2a` and
`us-west-2b`. I verified that both public subnets route internet traffic
through the internet gateway and both private subnets route it through
one NAT gateway in `us-west-2a`. A follow-up `terraform plan` reported
no changes across the 14 managed resources.

- [Terraform network plan](docs/screenshots/12-terraform-network-plan.png)
- [Terraform apply](docs/screenshots/13-terraform-network-apply.png)
- [Live subnets, NAT gateway, and route tables](docs/screenshots/14-aws-network-routing.png)
