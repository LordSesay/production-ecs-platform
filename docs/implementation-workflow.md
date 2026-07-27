# Start-to-End Implementation Workflow

## Gate 0 — Ownership and scope

- Create a new GitHub repository, not a fork.
- Initialize a new Git history.
- Use original application source and documentation.
- Record the architecture and acceptance criteria before AWS provisioning.

Exit condition: the repository shows no fork relationship and has one coherent
delivery model.

## Gate 1 — Application

- Implement `/api/health` and `/api/platform`.
- Build a web console that consumes the API.
- Add type checks, unit tests, production builds, and graceful API shutdown.

Exit condition: `npm run validate` passes.

## Gate 2 — Containers

- Add multi-stage images.
- Run as non-root users.
- Include container health checks.
- Keep runtime images free of development dependencies.
- Verify same-origin `/api` routing through the web entrypoint.

Exit condition: Docker Compose reports both services healthy and smoke tests
return the expected commit metadata.

## Gate 3 — AWS foundation

- Configure remote Terraform state.
- Provision VPC, two-AZ subnets, routes, NAT, security groups, ALB, ECR, ECS
  cluster, IAM roles, log groups, and alarms.
- Keep workload tasks private and expose only the ALB.

Exit condition: Terraform validation and plan review pass; outputs identify the
ECR URLs, cluster, ALB, and deployer role.

## Gate 4 — First workload release

- Build images with a Git commit SHA tag.
- Push both images to ECR.
- Apply the workload stack with those immutable image URIs.
- Verify target health, API health, version, and commit SHA.

Exit condition: the ALB serves the console and the API reports the deployed
commit.

## Gate 5 — Jenkins CI/CD

- Run Jenkins with an IAM role instead of long-lived AWS keys.
- Store no credentials in the Jenkinsfile or repository.
- Detect GitHub changes through SCM polling from the private controller.
- Test, build, scan, push, deploy, wait, and smoke-test.
- Serialize production deployment stages.

Exit condition: a new source commit is deployed without manual AWS console
changes and can be traced from Git commit to ECS task revision.

## Gate 6 — Operations

- Confirm CloudWatch logs for both services.
- Trigger and observe a failed health check.
- Confirm ECS circuit-breaker rollback.
- Test scaling policy behavior.
- Document rollback and incident checks.

Exit condition: the runbook is proven with captured evidence.

## Gate 7 — Professional handoff

- Review the complete diff and commit history.
- Add diagrams and sanitized evidence.
- Open a pull request for the implementation branch.
- Update the résumé and LinkedIn narrative only with verified facts.

Exit condition: another engineer can reproduce the platform from the README
without private knowledge or console-only steps.
