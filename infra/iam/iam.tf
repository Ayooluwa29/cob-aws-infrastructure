terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.81.0"
    }
  }

  backend "s3" {
    bucket       = "cob-bstrap-tfstate"
    key          = "envs/dev/iam/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
}

module "iam" {
  # Pin to a tag (e.g. iam-v0.1.0) once you create one.
  source = "git::https://github.com/Ayooluwa29/cob-terraform-modules-aws.git//modules/iam?ref=main"

  name_prefix = "${local.prefix}-"
  tags        = { Project = upper(var.project), Environment = var.environment, ManagedBy = "terraform", Stack = "iam" }

  policies = local.policies
  groups   = local.groups
}

output "group_arns" {
  value = module.iam.group_arns
}

output "policy_arns" {
  value = module.iam.policy_arns
}