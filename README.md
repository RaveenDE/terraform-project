# Terraform AWS Web Stack

Terraform configuration that provisions a small public web environment on **AWS** in **us-east-1**: a VPC with two public subnets, an Application Load Balancer (ALB) in front of two EC2 instances running Apache, plus an S3 bucket for static assets.

## What gets created

| Resource | Purpose |
|----------|---------|
| **VPC** | Custom network (`cidr` variable, default `10.0.0.0/16`) |
| **Subnets** | `10.0.0.0/24` (us-east-1a), `10.0.1.0/24` (us-east-1b), public IPs on launch |
| **Internet gateway & route table** | Default route `0.0.0.0/0` to the internet for both subnets |
| **Security group** | Inbound TCP 80 and 22 from `0.0.0.0/0`; outbound all |
| **S3 bucket** | `devops-terraform-project-bucket` with `public-read` ACL |
| **EC2 × 2** | `t3.micro`, Ubuntu AMI `ami-04680790a315cd58d`, user data from `userdata.sh` / `userdata1.sh` |
| **ALB** | Internet-facing HTTP listener on port 80, target group on port 80 with health checks on `/` |

After apply, Terraform outputs **`alb_dns_name`** — use that URL in a browser to hit the load balancer.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) **1.x** (compatible with AWS provider `~> 4.0`)
- An AWS account and credentials configured (for example [environment variables](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html) or `~/.aws/credentials`)
- Permission to create VPC, EC2, ELB, S3, and IAM-related resources your org requires

## Project layout

```
.
├── main.tf          # VPC, subnets, ALB, EC2, S3, security group, outputs
├── provider.tf      # AWS provider and required_providers
├── variables.tf     # Input variables (e.g. VPC CIDR)
├── userdata.sh      # Bootstrap for instance in subnet 1 (Apache + sample HTML)
├── userdata1.sh     # Bootstrap for instance in subnet 2
└── README.md
```

## Usage

1. Clone or copy this directory and `cd` into it.

2. (Optional) Adjust **`variables.tf`** — e.g. change `cidr` if it conflicts with another VPC.

3. **S3 bucket name** is fixed in `main.tf` as `devops-terraform-project-bucket`. S3 bucket names are globally unique; if apply fails with a name conflict, change the `bucket` attribute in the `aws_s3_bucket.web` resource.

4. Initialize and apply:

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

5. When instances and the ALB are healthy, open the printed **`alb_dns_name`** in your browser.

To tear everything down:

```bash
terraform destroy
```

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `cidr` | `10.0.0.0/16` | CIDR block for the VPC |

## Outputs

| Name | Description |
|------|-------------|
| `alb_dns_name` | DNS name of the Application Load Balancer |

## Security notes

- The security group allows **SSH (22) and HTTP (80) from anywhere** (`0.0.0.0/0`). That is convenient for labs but **not** appropriate for production; restrict `cidr_blocks` to your IP or a bastion.
- The S3 bucket uses **`public-read`** ACL. Review bucket policy and public access settings before using real data.
- Do not commit **`terraform.tfstate`** or secrets to version control. Add a `.gitignore` for `.terraform/`, `*.tfstate`, `*.tfstate.*`, and `.terraform.lock.hcl` only if your team policy allows excluding the lock file.

## Region and AMI

The provider region is **`us-east-1`**. The EC2 AMI ID is pinned in `main.tf`; if it ages out, replace it with a current Ubuntu (or your chosen OS) AMI for that region.
