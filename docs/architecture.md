# Architecture Decision Record

## Purpose

Give a small team traceable, self-verifying container releases on AWS at lab
cost. The problem and the guarantees are defined once, in the
[README](../README.md#what-the-platform-guarantees). This record explains the
boundaries that enforce those guarantees and the trade-offs accepted.

## Application boundary

The ECS Release Console has two independently deployable services:

1. `web` serves the browser application.
2. `api` exposes health and deployment metadata under `/api`.

They are separate ECS services so each component can be deployed, scaled,
rolled back, and observed independently.

## Network boundary

The ALB is the only public application component. Fargate tasks use private
subnets and do not receive public IP addresses. Task security groups accept
traffic only from the ALB security group on the required container port.

The initial lab profile uses one NAT gateway to control cost. The production
profile supports one NAT gateway per Availability Zone to remove the
cross-AZ egress dependency.

## Delivery boundary

Terraform owns durable infrastructure and the baseline ECS task definitions.
The GitHub Actions release workflow owns application releases after bootstrap:

1. validate source
2. build images
3. scan images
4. push immutable commit-SHA tags
5. register new ECS task definition revisions
6. update the corresponding ECS services
7. wait for stable services
8. verify health and deployed commit metadata

The release workflow does not run `terraform apply` during an application release.
This keeps infrastructure changes reviewable and separates them from frequent
application deployments.

## Release boundary

`.github/workflows/release.yml` runs only after CI succeeds for a push to `main`.
The job declares the `prod` environment, whose required reviewer approves each
release before any AWS credentials are issued.

The job exchanges its GitHub OIDC token for short-lived credentials on one IAM
role. The role's trust policy accepts only tokens whose `sub` claim is
`repo:LordSesay/production-ecs-platform:environment:prod`, so other branches,
pull requests and forks cannot assume it. The role can push only to the two
application ECR repositories, update only the two known ECS services, register
task definitions, and pass only the ECS task and task execution roles.

Actions that run with those credentials are pinned to full commit SHAs. Deploy,
verify and rollback logic lives in `scripts/release-services.sh`, so it is the
same whether the workflow or an operator runs it.

## State boundary

The state bootstrap stack creates a versioned, encrypted S3 bucket with public
access blocked and insecure transport denied. Foundation, workload, and github-release
use separate remote state objects and S3 native lock files. Downstream stacks
read only the foundation outputs required to wire resources together.

## Bootstrap boundary

The foundation stack is applied before the workload stack because ECR
repositories must exist before the first images can be pushed. The ordered
bootstrap is:

1. apply foundation
2. build and push the first commit-SHA images
3. apply workload using those exact image URIs
4. run smoke tests
5. apply the GitHub release role and configure the `prod` environment

## Explicit limitations

- “Production-style” describes the engineering controls exercised by this
  portfolio environment; it does not claim a formal production SLA.
- Releases depend on GitHub Actions being available. If it is down, an
  operator can run `scripts/release-services.sh` with their own credentials.
- TLS requires an ACM certificate plus a DNS alias from `application_domain`
  to the ALB. DNS is managed outside this stack. HTTP can be used only for the
  initial lab verification and is not the final hardened state.
- The lab profile has one NAT gateway and therefore retains a single-AZ egress
  dependency. The multi-NAT profile removes that dependency at additional cost.
- No AWS deployment claim is valid until the evidence checklist contains
  sanitized output from the user's own account.

## Decision: release orchestration (accepted 2026-11-21)

**Context.** Releases were first implemented on a self-hosted Jenkins
controller on a private EC2 instance. The choice came from bootcamp practice,
not from a requirement, and the controller was never run live. Jenkins removed
in this change remains in Git history.

**Decision.** Run releases in GitHub Actions with OIDC federation to a scoped
IAM role.

**Reasons.** Every release requirement can be met without a self-hosted server:

| Requirement | How it is met |
|---|---|
| No stored AWS keys | OIDC issues short-lived credentials per run |
| Least privilege | The same scoped release policy, on a role only the `prod` environment can assume |
| Release only verified code | Runs only after a successful CI run for a push to `main` |
| Human approval | The `prod` environment's required reviewer |
| Prompt trigger | Native push events; Jenkins needed 5-minute polling because it had no ingress |

ECR, ECS and the ALB are reachable through public AWS endpoints, so a release
runner does not need to be inside the VPC.

**Trade-offs accepted.**

- Releases depend on GitHub's availability and on third-party actions, which
  are mitigated by SHA pinning and the scripted manual path.
- The release job runs on GitHub-hosted runners outside the AWS account.

**Consequences.**

- Removed: the Jenkins EC2 instance, its security group and SSM access, the
  manual controller setup, and `JENKINS_HOME` state that was lost whenever the
  instance was replaced.
- CI and CD now run in one system.
