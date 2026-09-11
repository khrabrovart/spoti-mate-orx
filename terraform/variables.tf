variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "aws_assume_role_arn" {
  description = "IAM role ARN to assume when managing resources in the member account"
  type        = string
  sensitive   = true
}
