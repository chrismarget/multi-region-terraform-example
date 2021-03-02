# Expect the module caller to supply an AWS provider aliased as "requesting".
# The accepting side provider is the default AWS provider, so we don't need to
# mention it.
provider "aws" { alias = "requesting" }

# To make a vpc peering connection, we need to know the VPC IDs on both sides.
variable "accepting_vpc_id" {}
variable "requesting_vpc_id" {}

# Interrogate AWS b/c we're giong to need to know the target region's name.
data "aws_region" "accepting" {}

# Interrogate AWS b/c we'll need to know details about the VPCs beyond just
# their ID numbers. Note that the accepting VPC is handled by the default
# provider (it lives in the default region) for this module, so we look it up
# using only its ID number. Lookup of the requesting VPC, on the other hand,
# requires us to use a non-default provider because it's in the other region.
data "aws_vpc" "accepting_vpc" {
  id = var.accepting_vpc_id
}
data "aws_vpc" "requesting_vpc" {
  id = var.requesting_vpc_id
  provider = aws.requesting                      # non-default provider
}

# Use non-default provider when creating the peering connection.
resource "aws_vpc_peering_connection" "x" {
  provider = aws.requesting                      # non-default provider
  peer_region = data.aws_region.accepting.name
  peer_vpc_id = data.aws_vpc.accepting_vpc.id
  vpc_id = data.aws_vpc.requesting_vpc.id
}

# Use default provider when creating the peering accepter.
resource "aws_vpc_peering_connection_accepter" "x" {
  vpc_peering_connection_id = aws_vpc_peering_connection.x.id
  auto_accept = true
}

# Add a route to both sides.
resource "aws_route" "requesting_side" {
  provider = aws.requesting                     # non-default provider
  route_table_id = data.aws_vpc.requesting_vpc.main_route_table_id
  destination_cidr_block = data.aws_vpc.accepting_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.x.id
}
resource "aws_route" "accepting_side" {
  route_table_id = data.aws_vpc.accepting_vpc.main_route_table_id
  destination_cidr_block = data.aws_vpc.requesting_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.x.id
}
