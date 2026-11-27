# Student Platform Infrastructure

This repository contains the Terraform configuration for the Student Management Platform on AWS. It provisions a two-zone VPC in `us-west-2`, an Amazon EKS cluster named `student-platform`, private worker nodes, and the Amazon EBS CSI driver used for MySQL storage.

The [application repository](https://github.com/sujanpakhrin/student-platform-app) contains the frontend, backend, and CI workflow. The [GitOps repository](https://github.com/sujanpakhrin/student-platform-gitops) contains the Helm chart, Argo CD configuration, and application deployment evidence.

## Terraform configuration

| File                             | Purpose                                                                                        |
| -------------------------------- | ---------------------------------------------------------------------------------------------- |
| [providers.tf](providers.tf)     | Terraform and AWS provider configuration.                                                      |
| [network.tf](network.tf)         | VPC and public and private subnets.                                                            |
| [routing.tf](routing.tf)         | Internet gateway, NAT gateway, Elastic IP, route tables, and subnet associations.              |
| [eks-iam.tf](eks-iam.tf)         | IAM roles and policy attachments for the EKS cluster and worker nodes.                         |
| [eks.tf](eks.tf)                 | EKS cluster, API endpoint access configuration, and managed node group.                        |
| [eks-storage.tf](eks-storage.tf) | EKS Pod Identity agent, EBS CSI driver add-on, and IAM permissions for the storage controller. |

## Network design

The VPC uses `10.20.0.0/16`. Each availability zone contains one public subnet and one private subnet.

| Availability zone | Public subnet  | Private subnet  |
| ----------------- | -------------- | --------------- |
| `us-west-2a`      | `10.20.0.0/24` | `10.20.10.0/24` |
| `us-west-2b`      | `10.20.1.0/24` | `10.20.11.0/24` |

Both public subnets route `0.0.0.0/0` through the internet gateway. The EKS workers run in the private subnets, whose default route points to a single NAT gateway in the public subnet in `us-west-2a`. Outbound internet access from workers in either zone therefore depends on that gateway.

## Provision the infrastructure

Run these commands from the repository root with AWS credentials authorized to provision the project resources. This project used the `capstone-tf` profile to obtain temporary credentials for the `CapstoneTerraformDeploy` role.

```bash
aws sts get-caller-identity --profile capstone-tf

terraform init
terraform validate
AWS_PROFILE=capstone-tf AWS_DEFAULT_REGION=us-west-2 \
  terraform plan -out=student-platform.tfplan
```

When prompted for `admin_ipv4_cidr`, enter the public IPv4 address of the machine that will access the EKS API, using `/32` notation. Review the planned network, cluster, worker, IAM, and storage resources before applying the saved plan.

```bash
AWS_PROFILE=capstone-tf AWS_DEFAULT_REGION=us-west-2 \
  terraform apply student-platform.tfplan
```

Keep saved plans, Terraform state, state backups, and credentials out of Git.

## Verify EKS workers and storage

Configure a named Kubernetes context and check worker readiness and placement:

```bash
aws eks update-kubeconfig \
  --name student-platform \
  --region us-west-2 \
  --profile capstone-tf \
  --alias capstone-eks

kubectl --context=capstone-eks get nodes -L topology.kubernetes.io/zone
```

During verification, both workers reported `Ready`, with one in `us-west-2a` and one in `us-west-2b`.

The EBS CSI driver allows Kubernetes workloads to use EBS volumes. Its controller uses EKS Pod Identity to obtain the AWS permissions defined in `eks-storage.tf`. Verify the controller, node plugin, and driver registration:

```bash
kubectl --context=capstone-eks -n kube-system rollout status \
  deployment/ebs-csi-controller --timeout=5m

kubectl --context=capstone-eks -n kube-system rollout status \
  daemonset/ebs-csi-node --timeout=5m

kubectl --context=capstone-eks get csidriver ebs.csi.aws.com
```

Both rollouts completed successfully and Kubernetes listed `ebs.csi.aws.com`. The GitOps chart configures the `student-platform-gp3` StorageClass and the MySQL claim. A `Bound` claim and a successful database lookup are verified during application deployment.

## Verification evidence

| Evidence                                                                        | What was verified                                                                                      |
| ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| [12 — Terraform network plan](docs/screenshots/12-terraform-plan.png)           | The initial network stage planned 14 resources.                                                        |
| [13 — Terraform network apply](docs/screenshots/13-terraform-network-apply.png) | Terraform provisioned the network. A follow-up plan reported no changes at that stage.                 |
| [14 — Live AWS routing](docs/screenshots/14-aws-network-routing.png)            | AWS showed four subnets, an available NAT gateway, and the expected public and private default routes. |
| [15 — EKS cluster and workers](docs/screenshots/15-eks-cluster-nodes.png)       | The EKS context and ready worker nodes were verified with `kubectl`.                                   |

## Troubleshooting

### EBS CSI add-on creation returned HTTP 403

AWS denied `eks:CreatePodIdentityAssociation` while Terraform was creating the EBS CSI add-on. The error identified the caller as the Terraform deployment role and the resource as the `student-platform` cluster.

I added the missing permission to the deployment role for that cluster and reran Terraform. I verified recovery by checking that the EBS CSI controller and node plugin rolled out and that Kubernetes registered the driver.

### Checking retained storage after teardown

The MySQL disk was provisioned through Kubernetes. After one teardown, `terraform state list` was empty while the detached EBS volume still existed in `us-west-2b`. When preserving database data for a rebuild, record the volume ID, availability zone, and original database credentials. When retiring the environment, verify the volume and NAT Elastic IP separately in AWS.
