# VPC peering with terraform

This project is a demonstration of using terraform provider aliasing and
modular resource layout to do work in multiple AWS regions within a single 
terraform project.

Specifically, we'll be creating a VPC in each of three regions, configuring VPC
peering between those regions, and establish routes so that resources created in
those regions can talk to one other.

![Interconnected resources in three regions](./diagram.svg?raw=true "Topology")


The project structure looks like this:
```
.
├── main.tf
├── provider.tf
├── variable.tf
├── versions.tf
├── per-region
│   └── main.tf
├── vpc
│   └── main.tf
└── vpc-peering
    └── main.tf
```
## Define multiple regions
The top-level project's provider configuration specifies multiple `aws`
providers and creates an alias for each one.
```
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us-east-2"
  region = "us-east-2"
}

provider "aws" {
  alias  = "ca-central-1"
  region = "ca-central-1"
}
```
Because of these `alias` directives, there is no default `aws` provider at the
top level of the project. We'll need to specify which provider we need when
when calling for any `aws` `resource` or `data` object at the top level.

## Repeating single-region work in multiple regions
Top-level `main.tf` calls the `per-region` module three times (once for each
region), and passes a different provider each time.

The `per-region` module doesn't directly create any resources. Rather, it exists
only to call other modules: Modules which are not aware that work is being done
in multiple regions, use only a default provider, and do not expect to need to
pick their configuration data out of a per-region map. Y'know, regular terraform
stuff.

To better understand the purpose of the `per-region` module, consider the
contents of `variable.tf`:
```
variable "cidr" {
  default = {
    us-east-1 = "172.20.0.0/24"
    us-east-2 = "172.20.1.0/24"
    ca-central-1 = "172.20.2.0/24"
  }
}
```
Top-level `main.tf` and the `per-region` module know the `cidr` values for all
three regions, but the `vpc` module (which doesn't know it's a clone) is
expecting something more like:
```
variable "cidr" { default = "172.20.0.0/24" }
```
The `per-region` problem solves that problem by looking up the correct element
from the `cidr` map and passing only that value when calling `vpc`:
```
module "vpc" {
  source = "../vpc"
  cidr = var.cidr[data.aws_region.current.name]
}
```
Additionally, because `main.tf` called `per-region` with only a
default/un-aliased `aws` provider, there's no confusion about which provider to
use when `vpc` is doing its work.

In a real project, `vpc` would be just one of many single-region modules called
by `per-region`. The `per-region` module isn't strictly required (`main.tf`
could call `vpc` directly with the correct variables), but as modules and
resources bloom, things get crowded fast, and I find the `per-region`
abstraction helpful. 

## Coordinating work across multiple regions
Top-level `main.tf` also calls the `vpc-peering` module. Like the `vpc` module,
it also winds up getting called three times. `vpc-peering` differs in that it
knows about multiple providers/regions because creating a VPC peering connection
requires doing coordinated work on both ends of the connection (in different
regions). It does not need to be "protected" from this information by an
intermediate module.

Calling the `vpc-peering` looks like:
```
module "peering_1" {
  source = "./vpc-peering"
  accepting_vpc_id = module.us_east_2.vpc_id
  requesting_vpc_id = module.us_east_1.vpc_id
  providers = {
    aws = aws.us-east-2                   # Default aws provider for module
    aws.requesting = aws.us-east-1        # Named/aliased provider for module
  }
}
```
Note that we're passing *two* providers to the module this time. Like before,
one provider serves as the `aws` default, but the second one is aliased
`aws.requesting`, and will need to be explicitly referenced when used within the
module. There is no requirement to pass a default provider. Aliasing both would
have worked as well. But aliasing only a single module saves some typing in the
`data` and `resource` stanzas within the module.

