# Operations Runbook

Set these operator variables before using the commands:

```bash
export AWS_REGION="us-east-1"
export ECS_CLUSTER="ecs-release-console-prod"
export WEB_SERVICE="ecs-release-console-prod-web"
export API_SERVICE="ecs-release-console-prod-api"
export APPLICATION_URL="http://replace-with-alb-dns"
```

## Service health

```bash
scripts/smoke-test.sh "${APPLICATION_URL}"

aws ecs describe-services \
  --region "${AWS_REGION}" \
  --cluster "${ECS_CLUSTER}" \
  --services "${WEB_SERVICE}" "${API_SERVICE}" \
  --query 'services[].{service:serviceName,running:runningCount,desired:desiredCount,task:taskDefinition,rollout:deployments[0].rolloutState}'
```

## Deployment events

```bash
aws ecs describe-services \
  --region "${AWS_REGION}" \
  --cluster "${ECS_CLUSTER}" \
  --services "${API_SERVICE}" \
  --query 'services[0].events[0:10].[createdAt,message]' \
  --output table
```

Look for target-health failures, task start failures, image-pull errors, and
deployment circuit-breaker messages.

## Application logs

```bash
aws logs tail "/ecs/ecs-release-console-prod/api" \
  --region "${AWS_REGION}" \
  --since 30m \
  --follow
```

Use `/web` for the web log group.

## Explicit rollback

Find the current and previous task revisions:

```bash
aws ecs list-task-definitions \
  --region "${AWS_REGION}" \
  --family-prefix "ecs-release-console-prod-api" \
  --sort DESC \
  --max-items 5
```

Then:

```bash
scripts/rollback-service.sh \
  "${AWS_REGION}" \
  "${ECS_CLUSTER}" \
  "${API_SERVICE}" \
  "arn:aws:ecs:REGION:ACCOUNT:task-definition/FAMILY:REVISION"
```

Always verify the application after rollback.

## Controlled failure exercise

Do not run this exercise during a real production event.

The exercise runs the same `release-services.sh` the release workflow uses, from
your own machine, so `main` is never broken.

1. Record both current task definition ARNs.
2. On a throwaway branch, break the API: for example, make `/api/health` return
   HTTP 500. Commit it, but do not merge it.
3. Build and push images for that commit:

   ```bash
   broken_sha=$(git rev-parse HEAD)
   scripts/build-and-push.sh "${AWS_REGION}" "${WEB_REPOSITORY}" "${API_REPOSITORY}" "${broken_sha}"
   ```

4. Release it by hand:

   ```bash
   export ECS_CLUSTER="ecs-release-console-prod"
   export API_ECS_SERVICE="${ECS_CLUSTER}-api" WEB_ECS_SERVICE="${ECS_CLUSTER}-web"
   export API_IMAGE_URI="${API_REPOSITORY}:sha-${broken_sha}"
   export WEB_IMAGE_URI="${WEB_REPOSITORY}:sha-${broken_sha}"
   export APP_ENVIRONMENT="prod" APP_VERSION="failure-exercise" COMMIT_SHA="${broken_sha}"
   export APPLICATION_URL="http://<alb-dns-name>"
   scripts/release-services.sh
   ```

5. Expect a non-zero exit, `Release failed; restoring both previous task
   definitions.` and two `Rolled back` lines. Check the service events for the
   ECS circuit breaker.
6. Confirm both services are back on the task definitions from step 1, then
   run `scripts/smoke-test.sh "${APPLICATION_URL}"` and capture sanitized output.
7. Delete the throwaway branch.

## Scaling exercise

Use a bounded load generator from an approved test environment. Observe:

```bash
aws cloudwatch get-metric-data ...
aws ecs describe-services ...
```

Confirm scale-out does not exceed `maximum_task_count` and scale-in returns no
lower than `minimum_task_count`. Do not claim scaling was tested based only on
the existence of a Terraform policy.

## Destruction order

Use the ordered teardown, which keeps every `terraform destroy` interactive:

```bash
export AWS_REGION="us-east-1"
export TF_STATE_BUCKET="your-state-bucket"
export PROJECT_NAME="ecs-release-console"
export ENVIRONMENT="prod"
export CONFIRM_DESTROY="ecs-release-console-prod"   # must equal <project>-<environment>

scripts/teardown-platform.sh
```

It runs, in order:

1. `github-release` destroy (set `CREATE_OIDC_PROVIDER=false` if the stack
   did not create the account's OIDC provider)
2. `workload` destroy, passing the currently running image URIs, because the
   stack's `aws_ecr_image` lookups need existing tags even during destroy
   (override with `WEB_IMAGE_URI` / `API_IMAGE_URI` if the services are gone)
3. ECR image purge, required because repositories use `force_delete = false`
4. `foundation` destroy

The state bucket is protected by `prevent_destroy` and is retained. Remove the
protection only after confirming no downstream state is needed. The logs KMS
key enters a 7-day pending-deletion window. If `enable_deletion_protection` was
set to `true`, set it back to `false` and apply before tearing down.
