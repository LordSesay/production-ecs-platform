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

- [ ] Web image builds
- [ ] API image builds
- [ ] Both containers report healthy in Docker Compose
- [ ] Same-origin `/api/platform` returns the expected local commit value
- [ ] Runtime processes are non-root

Evidence:

```text
Pending execution on a Docker-capable workstation.
```

## Gate 3 — Terraform foundation

- [ ] `terraform fmt -check` passes
- [ ] `terraform validate` passes for all four stacks
- [ ] Foundation plan was reviewed
- [ ] Public and private subnets exist in two Availability Zones
- [ ] ECS tasks have no public IP addresses
- [ ] ALB is the only application ingress
- [ ] ECR repositories are immutable and scan on push
- [ ] Terraform state is encrypted, versioned, blocked from public access, and locked

Evidence:

```text
Pending AWS plan and apply.
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
