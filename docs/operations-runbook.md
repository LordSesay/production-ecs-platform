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

1. Record both current task definition ARNs.
2. Create a feature branch that intentionally changes the API container health
   path to a nonexistent endpoint.
3. Run the pipeline and observe the failed deployment.
4. Confirm the ECS circuit breaker reports rollback.
5. Confirm the Jenkins rollback handler restores both previous task revisions.
6. Run the smoke test and capture sanitized evidence.
7. Revert the intentional change before merging.

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

Remove resources in reverse dependency order:

```bash
terraform -chdir=infrastructure/jenkins destroy
terraform -chdir=infrastructure/workload destroy
terraform -chdir=infrastructure/foundation destroy
```

The state bucket is protected by `prevent_destroy`. Retain it for audit and
recovery, or remove the protection only after confirming all downstream state
is no longer needed. ECR repositories use `force_delete = false`; delete images
deliberately before destroying the foundation.
