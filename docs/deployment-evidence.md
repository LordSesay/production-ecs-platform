# Deployment Evidence

This file is an honesty boundary. Do not check a box or add a résumé claim until
the corresponding output has been produced in the target AWS account.

Do not commit account IDs, credentials, private URLs, tokens, email addresses,
or unredacted console screenshots.

## Gate 1 — Application

- [x] API type check passed locally
- [x] Web type check passed locally
- [x] Five automated tests passed locally
- [x] API and web production builds passed locally

Evidence date: 2026-07-27.

## Gate 2 — Containers

- [x] Web image builds
- [x] API image builds
- [x] Both containers report healthy in Docker Compose
- [x] Same-origin `/api/platform` returns the expected local commit value
- [x] Runtime processes are non-root

Evidence:

```text
Evidence date: 2026-07-27.

- Docker Compose built and started the API and web containers.
- Both containers reached healthy status.
- `/health` and `/api/health` returned healthy responses.
- `/api/platform` returned service `ecs-release-api` with commit `local`.
- API ran as UID 10001 and web ran as UID 101.
```

## Gate 3 — Terraform foundation

- [x] `terraform fmt -check` passes
- [x] `terraform validate` passes for all four stacks
- [x] Foundation plan was reviewed
- [x] Public and private subnets exist in two Availability Zones
- [ ] ECS tasks have no public IP addresses
- [x] ALB is the only application ingress
- [x] ECR repositories are immutable and scan on push
- [x] Terraform state is encrypted, versioned, blocked from public access, and locked

Evidence:

```text
Evidence date: 2026-07-27.

- Remote Terraform state deployed with versioning, AES-256 encryption,
  public-access blocking, TLS-only access policy, and native locking.
- Foundation plan reviewed: 49 added, 0 changed, 0 destroyed.
- Foundation apply completed successfully.
- Post-apply Terraform drift check returned exit code 0.
- ALB reported active, internet-facing, and application type.
- ECS cluster reported ACTIVE with Container Insights enabled.
- API and web ECR repositories reported IMMUTABLE, scan-on-push enabled,
  and AES256 encryption.
- Four subnets were verified across us-east-1a and us-east-1b with automatic
  public IP assignment disabled.
```

## Gate 4 — First workload release

- [ ] Web and API images use the same `sha-<commit>` tag
- [ ] Two web and two API tasks reach running state
- [ ] Both target groups report healthy targets
- [ ] `/api/platform` returns the deployed commit
- [ ] CloudWatch contains structured API request logs

Evidence:

```text
Pending first AWS workload release.
```

## Gate 5 — Jenkins release

- [ ] Jenkins is private and reachable only through SSM
- [ ] Jenkins has no static AWS access keys
- [ ] SCM polling detects a new Git commit
- [ ] Test, scan, push, deploy, stabilize, and smoke stages pass
- [ ] Git SHA maps to ECR tags and ECS task revisions

Evidence:

```text
Pending live Jenkins build.
```

## Gate 6 — Operations

- [ ] A controlled failed health check was observed
- [ ] ECS circuit-breaker behavior was confirmed
- [ ] Scripted rollback restored prior revisions
- [ ] Alarm state transitions were observed
- [ ] Autoscaling behavior was exercised

Evidence:

```text
Pending controlled operational exercises.
```

## Approved portfolio claim

Use this only after Gates 2 through 6 have the required evidence:

> Designed and deployed a containerized application platform on Amazon ECS
> Fargate using Terraform, Docker, Amazon ECR, an Application Load Balancer, and
> Jenkins-based CI/CD. Automated infrastructure provisioning, immutable image
> delivery, and ECS service deployments while implementing public/private
> network segmentation, IAM controls, deployment health checks, and repeatable
> rollback practices.
