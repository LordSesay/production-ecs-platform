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

## Gate 5 — Automated release (GitHub Actions)

- [ ] The repository holds no AWS access-key secrets
- [ ] CloudTrail shows `AssumeRoleWithWebIdentity` for the release role from
      `token.actions.githubusercontent.com`
- [ ] A push to `main` ran CI, then waited for `prod` approval before release
- [ ] Build, scan, push, deploy, stabilize, and smoke steps pass
- [ ] The run summary maps the Git SHA to ECR tags and ECS task revisions

Evidence:

```text
Pending first release workflow run.
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

> Built and deployed a container release platform on Amazon ECS Fargate in
> which every running task traces to an immutable, commit-tagged image and a
> release that fails verification is rolled back automatically. Provisioned the
> VPC, ALB, ECR, ECS, KMS-encrypted logging and IAM with Terraform, and
> delivered releases through GitHub Actions using OIDC federation to a scoped,
> environment-restricted IAM role instead of stored AWS keys. Verified with commit-asserting smoke
> tests, a controlled failed-release exercise, and recorded rollback and
> scaling evidence.
