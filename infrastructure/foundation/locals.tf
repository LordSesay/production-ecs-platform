locals {
  name_prefix = "${var.project_name}-${var.environment}"
  azs         = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)

  public_subnets = {
    for index, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, index)
  }

  private_subnets = {
    for index, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, index + 16)
  }

  nat_gateway_azs = var.single_nat_gateway ? [local.azs[0]] : local.azs
  listener_arn    = var.certificate_arn == null ? aws_lb_listener.http[0].arn : aws_lb_listener.https[0].arn
  application_url = var.certificate_arn == null ? "http://${aws_lb.application.dns_name}" : "https://${var.application_domain}"
}

check "tls_configuration" {
  assert {
    condition = (
      (var.certificate_arn == null && var.application_domain == null) ||
      (var.certificate_arn != null && var.application_domain != null)
    )
    error_message = "certificate_arn and application_domain must either both be null or both be configured."
  }
}
