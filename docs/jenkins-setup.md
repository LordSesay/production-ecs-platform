# Jenkins Setup

The controller is deliberately private. It has no public IP address, SSH rule,
or inbound port 8080 rule. Access is through AWS Systems Manager.

## 1. Apply the Jenkins stack

Create a backend configuration using:

```hcl
bucket       = "your-state-bucket"
key          = "production-ecs-platform/prod/jenkins.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
```

Copy and edit `infrastructure/jenkins/terraform.tfvars.example`, then:

```bash
terraform -chdir=infrastructure/jenkins init \
  -backend-config=/absolute/path/to/jenkins-backend.hcl
terraform -chdir=infrastructure/jenkins validate
terraform -chdir=infrastructure/jenkins plan
terraform -chdir=infrastructure/jenkins apply
```

Wait until the instance is online in Systems Manager:

```bash
INSTANCE_ID="$(
  terraform -chdir=infrastructure/jenkins output -raw instance_id
)"
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=${INSTANCE_ID}"
```

## 2. Open the private UI

Install the AWS Session Manager plugin on the operator workstation. Print the
generated tunnel command:

```bash
terraform -chdir=infrastructure/jenkins output -raw ssm_tunnel_command
```

Run that command and keep the terminal open. Browse to:

```text
http://localhost:8080
```

Retrieve the one-time password from an SSM shell:

```bash
aws ssm start-session --target "${INSTANCE_ID}" --region us-east-1
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## 3. Install only the needed plugins

Install the suggested plugins, then confirm these capabilities are present:

- Pipeline
- Git
- Credentials Binding
- Timestamper

Do not install AWS credential plugins for this project. AWS CLI calls receive
short-lived credentials from the EC2 instance role.

## 4. Create the pipeline job

1. Select **New Item**.
2. Name it `production-ecs-platform`.
3. Choose **Pipeline**.
4. Under **Pipeline**, select **Pipeline script from SCM**.
5. Select **Git** and enter the new repository URL.
6. Set the branch to `*/main`.
7. Set the script path to `Jenkinsfile`.
8. Save and run **Build Now** once.

For a public repository, no Git credential is needed. For a private repository,
store a narrow GitHub credential in Jenkins and bind it only to the SCM
checkout. Never place a GitHub token in the repository or Jenkinsfile.

## 5. Configure pipeline parameters

The first run exposes parameters. Populate them from Terraform outputs:

| Parameter | Source |
|---|---|
| `AWS_REGION` | Foundation Region |
| `WEB_ECR_REPOSITORY` | `ecr_repository_urls.web` |
| `API_ECR_REPOSITORY` | `ecr_repository_urls.api` |
| `ECS_CLUSTER` | `ecs_cluster_name` |
| `WEB_ECS_SERVICE` | Workload `service_names.web` |
| `API_ECS_SERVICE` | Workload `service_names.api` |
| `APPLICATION_URL` | Workload `application_url` |
| `APP_ENVIRONMENT` | `prod` |
| `APP_VERSION` | Release version |

## 6. Trigger behavior

The controller polls the configured Git repository every five minutes because
it has no public ingress. This is the secure first implementation for the lab.
A direct webhook is intentionally not claimed.

## 7. Successful release evidence

A successful build must show:

1. source checkout and full Git SHA
2. type checks, tests, and production builds
3. two Docker image builds
4. critical-vulnerability scan gate
5. immutable ECR image publication
6. two new ECS task revisions
7. both services reaching stable state
8. `/api/platform` returning the exact deployed commit

If deployment or verification fails, the pipeline calls the rollback script for
both services and waits for their previous task definitions to stabilize.
