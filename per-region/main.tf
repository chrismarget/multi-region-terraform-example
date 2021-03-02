data "aws_region" "current" {}

variable "cidr" {}

module "vpc" {
  source = "../vpc"
  cidr = var.cidr[data.aws_region.current.name]
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
