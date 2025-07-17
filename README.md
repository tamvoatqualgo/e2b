# E2B on AWS Deployment Guide

## Introduction

### Purpose

E2B on AWS provides a secure, scalable, and customizable environment for running AI agent sandboxes in your own AWS account. This project addresses the growing need for organizations to maintain control over their AI infrastructure while leveraging the power of E2B's sandbox technology for AI agent development, testing, and deployment.

This project is built based on version [c746fd93d5f1260315c893dbd5d7290c0a41e52a](https://github.com/e2b-dev/infra/commit/c746fd93d5f1260315c893dbd5d7290c0a41e52a) (Mar 2), with newer versions still undergoing modifications. This E2B deployment can be used for testing purposes. If you encounter any issues, please contact the relevant team members or submit a PR directly. We would like to express our special thanks to all contributors involved in the project transformation.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Deployment Steps](#deployment-steps)
  - [1. Setup E2B Landing Zone](#1-setup-e2b-landing-zone)
  - [2. Setup E2B Infrastructure](#2-setup-e2b-infrastructure)
  - [3. Deploy E2B Applications](#3-deploy-e2b-applications)
  - [4. Configure E2B Monitoring (Optional)](#4-configure-e2b-monitoring-optional)
  - [5. Test by E2B SDK](#5-test-by-e2b-sdk)
- [Using E2B CLI](#using-e2b-cli)
- [E2B SDK Cookbook](#e2b-sdk-cookbook)
- [Troubleshooting](#troubleshooting)
- [Resource Cleanup Recommendations](#resource-cleanup-recommendations)
- [Appendix](#appendix)
- [Architecture Diagram](#architecture-diagram)

## Prerequisites

- An AWS account with appropriate permissions
- A domain name that you own(Cloudflare is recommended, or using a private dns for internal connection only)
- Recommended for monitoring and logging
  - Grafana Account & Stack (see Step 15 for detailed notes)
  - Posthog Account (optional)

> **Production Security Checklist:** Before deploying to production, verify these critical security and reliability settings are enabled:
> - `DB_INSTANCE_BACKUP_ENABLED`
> - `RDS_AUTOMATIC_MINOR_VERSION_UPGRADE_ENABLED`
> - `RDS_ENHANCED_MONITORING_ENABLED`
> - `RDS_INSTANCE_LOGGING_ENABLED`
> - `RDS_MULTI_AZ_SUPPORT`
> - `S3_BUCKET_LOGGING_ENABLED`
> - `EC2 Metadata service configuration`

## Deployment Steps

### 1. Setup E2B Landing Zone

1. **Deploy CloudFormation Stack**
   - Open AWS CloudFormation console and create a new stack
   - Upload the `e2b-setup-env.yml` template file
   - Configure the following parameters:
     - **Stack Name**: Enter a name for the stack, **must be lowercase**(e.g., `e2b-infra`)
     - **Domain Configuration**: Enter a domain you own (e.g., `example.com`), for using private host, check [Configure Private Hosted Zone] part
     - **EC2 Key Pair**: Select an existing key pair for SSH access
     - **AllowRemoteSSHIPs**: Adjust IP range for SSH access (default restricts to private networks for security)
     - **Database Settings**: Configure RDS parameters following password requirements(must be 8-30 characters with only letters and numbers, **special characters are not allowed**)
   - Complete all required fields and launch the stack

2. **Validate Domain Certificate**
   - Navigate to Amazon Certificate Manager (ACM)
   - Find your domain certificate and note the required CNAME record
   - Add the CNAME record to your domain's DNS settings(Cloudflare DNS settings)
   - Wait for domain validation (typically 5-10 minutes)

3. **Monitor Stack Creation**
   - Return to CloudFormation console
   - Wait for stack creation to complete successfully

### 2. Setup E2B Infrastructure

1. **Connect to Deployment Machine**
   - Use SSH with your EC2 key pair: `ssh -i your-key.pem ubuntu@<instance-ip>`
   - Or use AWS Session Manager from the EC2 console for browser-based access

2. Execute the following commands:
```bash 
# Switch to root user for administrative privileges required for infrastructure setup
sudo su root

# Enter the working directory.
cd /opt/infra/sample-e2b-on-aws

# Initialize the environment by setting up AWS metadata, CloudFormation outputs,
# and creating the configuration file at /opt/config.properties

bash infra-iac/init.sh

# Build custom AMI images using Packer for the E2B infrastructure
# This creates optimized machine images with pre-installed dependencies
# This may take a while, please be patient
bash infra-iac/packer/packer.sh

# Deploy the complete E2B infrastructure using Terraform
# This provisions AWS resources including VPC, EC2 instances, RDS, ALB, etc.
# Wait until the terraform deployment completes
bash infra-iac/terraform/start.sh
```

3. Setup Database:
```bash
bash infra-iac/db/init-db.sh

# Save the following token information for later use:
# User: xxx
# Team ID: <ID>
# Access Token: <e2b_token>
# Team API Key: <e2b_API>
```
4. Configure E2B DNS records(in Cloudflare):
   - **Setup Wildcard DNS**: Add a CNAME record for `*` (wildcard) pointing to the DNS name of the automatically created Application Load Balancer (ALB). This enables all E2B subdomains to route through the load balancer.
   - **Access Nomad Dashboard**: Navigate to `https://nomad.<your-domain>` in your browser and authenticate using the retrieved token to monitor and manage the Nomad cluster workloads.
   - **Retrieve Nomad Access Token**: Execute `more /opt/config.properties | grep NOMAD` to extract the Nomad cluster management token from the configuration file.

### 3. Deploy E2B Applications

#### Application Image Configuration

**Custom Image Building**
- **Build Custom Images**: Execute `bash packages/build.sh` to build custom E2B images and push them to your private ECR registry

#### Deploy Nomad Applications

```bash
# Load Nomad environment variables and configuration settings
source nomad/nomad.sh

# Prepare the Nomad cluster and configure job templates
bash nomad/prepare.sh

# Deploy all E2B applications to the Nomad cluster
bash nomad/deploy.sh

# There are 10 applications in total
```

### 4. Configure E2B Monitoring (Optional)

1. Login to https://grafana.com/ (register if needed)
2. Access your settings page at https://grafana.com/orgs/<username>
3. In your Stack, find 'Manage your stack' page
4. Find 'OpenTelemetry' and click 'Configure'
5. Note the following values from the dashboard:
   ```
   Endpoint for sending OTLP signals: xxxx
   Instance ID: xxxxxxx
   Password / API Token: xxxxx
   ```

6. Export NOMAD environment variables:（Optional）
```bash
cat << EOF >> /opt/config.properties

# Grafana configuration
grafana_otel_collector_token=xxx
grafana_otlp_url=xxx
grafana_username=xxx
EOF

echo "Appended Grafana configuration to /opt/config.properties"
```

7. Deploy OpenTelemetry collector:（Optional）
```bash
bash nomad/deploy.sh otel-collector
```

8. Open Grafana Cloud Dashboard to view metrics, traces, and logs（Optional）


### 5. Test by E2B SDK

1. Create a template:
```bash
# Create a template from e2bdev/code-interpreter 
bash packages/create_template.sh

# Create a template from a Dockerfile
bash packages/create_template.sh --docker-file <Docker_File_Path>

# Create a template from an ECR image that in your own account
bash packages/create_template.sh --ecr-image <ECR_IMAGE_URI>
```

2. Create a sandbox(Get the value of e2b_API to execute commands---  more ../infra-iac/db/config.json):
```bash
curl -X POST \
 https://api.<e2bdomain>/sandboxes \
 -H "X-API-Key: <e2b_API>" \
 -H 'Content-Type: application/json' \
 -d '{
        "templateID": "<template_ID>",
        "timeout": 3600,
        "autoPause": true,
        "metadata": {
            "purpose": "test"
        }
 }'
```

## Using E2B CLI

```bash
# Installation Guide: https://e2b.dev/docs/cli
# For macOS
brew install e2b

# Export environment variables(you can query the  accessToken and teamApiKey in /opt/config.properties)
export E2B_API_KEY=xxx
export E2B_ACCESS_TOKEN=xxx
export E2B_DOMAIN="<e2bdomain>"

# Common E2B CLI commands
# List all sandboxes
e2b sandbox list
 
# Connect to a sandbox
e2b sandbox connect <sandbox-id>
 
# Kill a sandbox
e2b sandbox kill <sandbox-id>
e2b sandbox kill --all
```

## E2B SDK Cookbook

```bash
git clone https://github.com/e2b-dev/e2b-cookbook.git
cd e2b-cookbook/examples/hello-world-python
poetry install

# Edit .env file
vim .env
# Change E2B_API_KEY value

poetry run start
```

## Configure Private Hosted Zone

To avoid using external domain names and configure a private hosted zone for internal access, follow these steps:

### 1. Create Private Hosted Zone in Route53

1. **Navigate to Route53 Console**

   - Go to AWS Route53 console
   - Click "Create Hosted Zone"
2. **Configure Hosted Zone Settings**

   - **Domain name**: Enter your domain (e.g., `xiamingyang.site`)
   - **Type**: Select "Private hosted zone"
   - **VPC**: Select the region and VPC where your E2B infrastructure is deployed
   - Click "Create hosted zone"

### 2. Configure DNS Records

After completing the `bash infra-iac/terraform/start.sh` step, an Application Load Balancer (ALB) will be created. You need to configure a CNAME record in your private hosted zone:

1. **Create Wildcard CNAME Record**
   - **Record name**: `*` (wildcard)
   - **Record type**: `CNAME`
   - **Value**: Enter the DNS name of the ALB (e.g., `e2btest-public-alb-1491434189.us-west-2.elb.amazonaws.com`)
   - **TTL**: 300 (default)
   - Click "Create records"

### 3. Test the Configuration

You can test the private hosted zone configuration using the following methods:

**Test DNS Resolution:**

```bash
dig test.<your-domain-name>
```

**Example output:**

```
; <<>> DiG 9.18.30-0ubuntu0.22.04.2-Ubuntu <<>> test.xiamingyang.site
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 29956
;; flags: qr rd ra; QUERY: 1, ANSWER: 3, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 65494
;; QUESTION SECTION:
;test.xiamingyang.site. IN A

;; ANSWER SECTION:
test.xiamingyang.site. 300 IN CNAME e2btest-public-alb-1491434189.us-west-2.elb.amazonaws.com.
e2btest-public-alb-1491434189.us-west-2.elb.amazonaws.com. 60 IN A 52.39.63.230
e2btest-public-alb-1491434189.us-west-2.elb.amazonaws.com. 60 IN A 52.39.227.199

;; Query time: 3 msec
;; SERVER: 127.0.0.53#53(127.0.0.53) (UDP)
;; WHEN: Tue Jun 24 10:25:29 UTC 2025
;; MSG SIZE rcvd: 153
```

**Test HTTPS Access:**

```bash
curl -v https://nomad.<your-domain-name>
```

This should successfully connect to your Nomad dashboard through the ALB endpoint, confirming that the private hosted zone is working correctly.

### 4. Important Notes

- **E2B CLI Installation**: If you encounter Node.js version issues when installing E2B CLI on the deployment machine, you may need to upgrade Node.js:

  ```bash
  # Add NodeSource repository for Node.js 18
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -

  # Install Node.js
  sudo apt-get install -y nodejs

  # Verify version
  node -v

  # Reinstall E2B CLI
  sudo npm uninstall -g @e2b/cli
  sudo npm install -g @e2b/cli
  ```
- **External Domain Requirements**: For E2B CLI usage on macOS or external machines, you may still need to configure external domain access through your public DNS provider (e.g., Cloudflare).
- **VPC Access**: The private hosted zone only works within the specified VPC. Ensure your client machines are within the same VPC or have appropriate VPC connectivity.

## Troubleshooting

1. **No nodes were eligible for evaluation error when deploying applications**
   - Check node status and constraints

2. **Driver Failure: Failed to pull from ECR**
   - Error: `Failed to pull xxx.dkr.ecr.us-west-2.amazonaws.com/e2b-orchestration/api:latest: API error (404): pull access denied for xxx.dkr.ecr.us-west-2.amazonaws.com/e2b-orchestration/api, repository does not exist or may require 'docker login': denied: Your authorization token has expired. Reauthenticate and try again.`
   - Solution: Execute `aws ecr get-login-password --region us-east-1` to get a new ECR token and update the HCL file

3. For other unresolved issues, contact support

## Resource Cleanup Recommendations

When you need to delete the E2B environment, follow these steps:

1. **Terraform Resource Cleanup**:
   - Navigate to the Terraform directory: `cd ~/infra-iac/terraform/`
   - Run `terraform destroy` to remove infrastructure resources
   - **Note**: Some resources have deletion protection enabled and cannot be deleted directly:
     - **S3 Buckets**: You must manually empty these buckets before they can be deleted
     - **Application Load Balancers (ALB)**: These may require manual deletion through the AWS console

2. **CloudFormation Stack Cleanup**:
   - **RDS Database**: The database has deletion protection enabled for compliance reasons
     - First disable deletion protection through the RDS console
     - Then delete the CloudFormation stack

3. **Manual Resource Verification**:
   - After running the automated cleanup steps, verify in the AWS console that all resources have been properly removed
   - Check for any orphaned resources in:
     - EC2 (instances, security groups, load balancers)
     - S3 (buckets)
     - RDS (database instances)
     - ECR (container repositories)

## Appendix
## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This project is licensed under the Apache-2.0 License.

#### Application Image Configuration
