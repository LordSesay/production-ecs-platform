# AWS Deployment Runbook

This runbook turns the repository into a live platform in dependency order.
Nothing in this document requires AWS access keys inside the repository.

## 1. Preconditions

Install and verify:

- AWS CLI v2
- Terraform 1.10 or newer
- Docker Engine with Compose
- Git
- Node.js 22 or newer
- `jq`

Authenticate with an AWS CLI profile or AWS IAM Identity Center session, then
run:

```bash
aws sts get-caller-identity
scripts/check-prerequisites.sh
```

Confirm the account and Region before creating resources. Use a sandbox account
or an explicitly approved engineering account.

## 2. Establish source ownership

Create an empty GitHub repository named `production-ecs-platform`. Do not select
a README, license, or `.gitignore` during GitHub creation because those files
already exist locally.

From this project directory:

```bash
git init
git switch -c main
git add .
git commit -m "feat: establish ECS application platform"
git remote add origin https://github.com/LordSesay/production-ecs-platform.git
git push -u origin main
```

Use a feature branch for later infrastructure changes:

```bash
git switch -c feature/aws-foundation
```

## 3. Review cost and naming

Choose:

- one AWS Region
- a globally unique S3 state bucket name
- project name `ecs-release-console`
- environment `prod`

The default deployment creates a NAT gateway, ALB, four Fargate tasks, ECR
repositories, CloudWatch resources, and one `t3.small` EC2 instance. These are
billable even when no user is visiting the application.

## 4. Bootstrap remote state

Copy and edit the example file:

```bash
cp infrastructure/bootstrap-state/terraform.tfvars.example \
  infrastructure/bootstrap-state/terraform.tfvars
```

Then:

```bash
terraform -chdir=infrastructure/bootstrap-state init
terraform -chdir=infrastructure/bootstrap-state fmt -check
terraform -chdir=infrastructure/bootstrap-state validate
terraform -chdir=infrastructure/bootstrap-state plan
terraform -chdir=infrastructure/bootstrap-state apply
```

The state bucket is protected with `prevent_destroy`. Its versions must be
retained until every downstream stack has been safely removed.

## 5. Apply the foundation

Create a local `foundation-backend.hcl` outside the repository or in a temporary
directory:

```hcl
bucket       = "your-state-bucket"
key          = "production-ecs-platform/prod/foundation.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
```

Initialize and review:

```bash
terraform -chdir=infrastructure/foundation init \
  -backend-config=/absolute/path/to/foundation-backend.hcl
terraform -chdir=infrastructure/foundation fmt -check
terraform -chdir=infrastructure/foundation validate
terraform -chdir=infrastructure/foundation plan
terraform -chdir=infrastructure/foundation apply
terraform -chdir=infrastructure/foundation output
```

Exit criteria:

- public and private subnets span two Availability Zones
- only the ALB has public ingress
- ECS task security groups accept traffic only from the ALB
- ECR repositories are private, immutable, and scan on push

## 6. Publish the first immutable images

Use the current full commit SHA:

```bash
COMMIT_SHA="$(git rev-parse HEAD)"
WEB_REPOSITORY="$(
  terraform -chdir=infrastructure/foundation output -json ecr_repository_urls |
  jq -r .web
)"
API_REPOSITORY="$(
  terraform -chdir=infrastructure/foundation output -json ecr_repository_urls |
  jq -r .api
)"

scripts/build-and-push.sh \
  us-east-1 \
  "${WEB_REPOSITORY}" \
  "${API_REPOSITORY}" \
  "${COMMIT_SHA}"
```

The script reuses an existing immutable tag on a rerun but never overwrites it.

## 7. Apply the workload

Create `workload-backend.hcl` with the workload state key:

```hcl
bucket       = "your-state-bucket"
key          = "production-ecs-platform/prod/workload.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
```

Copy `infrastructure/workload/terraform.tfvars.example` to
`terraform.tfvars`, then replace the account ID, bucket name, image URIs, and
commit SHA with the values produced in the previous steps.

```bash
terraform -chdir=infrastructure/workload init \
  -backend-config=/absolute/path/to/workload-backend.hcl
terraform -chdir=infrastructure/workload fmt -check
terraform -chdir=infrastructure/workload validate
terraform -chdir=infrastructure/workload plan
terraform -chdir=infrastructure/workload apply
```

Verify the runtime contract:

```bash
APPLICATION_URL="$(
  terraform -chdir=infrastructure/workload output -raw application_url
)"
scripts/smoke-test.sh "${APPLICATION_URL}" "${COMMIT_SHA}"
```

## 8. Apply and configure Jenkins

Follow [Jenkins setup](jenkins-setup.md). Do not create AWS access-key
credentials in Jenkins; the EC2 instance profile already provides the bounded
release permissions.

## 9. Automated alternative

After reviewing the manual sequence, the following wrapper performs the same
ordered operations. Each Terraform apply remains interactive:

```bash
export AWS_REGION="us-east-1"
export TF_STATE_BUCKET="your-globally-unique-state-bucket"
export PROJECT_NAME="ecs-release-console"
export ENVIRONMENT="prod"
export APP_VERSION="0.1.0"
export CONFIRM_AWS_CHARGES="yes"

scripts/bootstrap-platform.sh
```

## 10. Evidence and claim gate

Complete [deployment evidence](deployment-evidence.md) with sanitized command
output. Only after every required check passes should the project narrative use
the words “designed and deployed.”
