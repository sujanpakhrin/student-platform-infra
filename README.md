## AWS network verification

Terraform provisioned a VPC and four subnets across `us-west-2a` and
`us-west-2b`. I verified that both public subnets route internet traffic
through the internet gateway and both private subnets route it through
one NAT gateway in `us-west-2a`. A follow-up `terraform plan` reported
no changes across the 14 managed resources.

- [Terraform network plan](docs/screenshots/12-terraform-network-plan.png)
- [Terraform apply](docs/screenshots/13-terraform-network-apply.png)
- [Live subnets, NAT gateway, and route tables](docs/screenshots/14-aws-network-routing.png)

## EKS storage

Terraform configured the EBS CSI driver and its IAM role in [eks-storage.tf](eks-storage.tf). The first add-on creation attempt returned a 403 because the Terraform deployment role lacked `eks:CreatePodIdentityAssociation` for the `student-platform` cluster. After adding that permission and provisioning the add-on, I verified that the controller Deployment and node DaemonSet rolled out successfully and Kubernetes listed `ebs.csi.aws.com`.

The [GitOps repository](https://github.com/sujanpakhrin/student-platform-gitops#day-5--eks-deployment-and-gitops-verification) contains the application configuration and live deployment evidence.
