# Architecture Decision Record

## Purpose

Build a production-style, cost-conscious ECS application platform that clearly
demonstrates networking, containers, infrastructure as code, IAM, continuous
delivery, and operational verification.

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
Jenkins owns application releases after bootstrap:

1. validate source
2. build images
3. scan images
4. push immutable commit-SHA tags
5. register new ECS task definition revisions
6. update the corresponding ECS services
7. wait for stable services
8. verify health and deployed commit metadata

Jenkins does not run routine `terraform apply` during an application release.
This keeps infrastructure changes reviewable and separates them from frequent
application deployments.

## Jenkins boundary

The controller runs on a private EC2 instance with no public IP address and no
inbound security-group rules. Operators reach port 8080 through an authenticated
AWS Systems Manager port-forwarding session. The instance profile can push only
to the two application ECR repositories, update only the two known ECS
services, register task definitions, and pass only the ECS task roles.

Because the controller has no public ingress, the initial implementation uses
Jenkins SCM polling every five minutes. It does not claim direct GitHub webhook
delivery. A future webhook design must introduce a separately authenticated
ingress path without exposing the Jenkins controller.

## State boundary

The state bootstrap stack creates a versioned, encrypted S3 bucket with public
access blocked and insecure transport denied. Foundation, workload, and Jenkins
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
5. configure the private Jenkins controller and SCM polling

## Explicit limitations

- “Production-style” describes the engineering controls exercised by this
  portfolio environment; it does not claim a formal production SLA.
- A single-node Jenkins controller is not highly available. It is a delivery
  system for the lab, while the ECS workload itself spans two Availability
  Zones.
- TLS requires an ACM certificate plus a DNS alias from `application_domain`
  to the ALB. DNS is managed outside this stack. HTTP can be used only for the
  initial lab verification and is not the final hardened state.
- The lab profile has one NAT gateway and therefore retains a single-AZ egress
  dependency. The multi-NAT profile removes that dependency at additional cost.
- No AWS deployment claim is valid until the evidence checklist contains
  sanitized output from the user's own account.
