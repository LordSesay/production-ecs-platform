data "terraform_remote_state" "foundation" {
  backend = "s3"

  config = {
    bucket       = var.state_bucket_name
    key          = var.foundation_state_key
    region       = var.aws_region
    use_lockfile = true
    encrypt      = true
  }
}

data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
