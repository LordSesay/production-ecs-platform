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

data "aws_ecr_image" "release" {
  for_each = {
    web = {
      repository_name = split("/", data.terraform_remote_state.foundation.outputs.ecr_repository_urls.web)[1]
      image_uri       = var.web_image_uri
    }
    api = {
      repository_name = split("/", data.terraform_remote_state.foundation.outputs.ecr_repository_urls.api)[1]
      image_uri       = var.api_image_uri
    }
  }

  repository_name = each.value.repository_name
  image_tag       = split(":", each.value.image_uri)[1]
}
