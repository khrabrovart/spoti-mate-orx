terraform {
  required_version = ">= 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.15"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
  }

  backend "s3" {
    bucket  = "arturkhrabrov-tfstate"
    key     = "spoti-mate-orx/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "SpotiMateOrx"
      ManagedBy = "Terraform"
    }
  }
}

locals {
  app_name = "spoti-mate"

  # 1st at midday on Mar, Jun, Sep, and Dec.
  notifier_schedule_expression          = "cron(0 12 1 3,6,9,12 ? *)"
  notifier_schedule_expression_timezone = "Europe/Warsaw"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
