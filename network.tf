data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}

locals {
  zones = sort(data.aws_availability_zones.available.names)

  subnets = {
    public_1  = { zone = local.zones[0], cidr = "10.20.0.0/24" }
    public_2  = { zone = local.zones[1], cidr = "10.20.1.0/24" }
    private_1 = { zone = local.zones[0], cidr = "10.20.10.0/24" }
    private_2 = { zone = local.zones[1], cidr = "10.20.11.0/24" }
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "student-platform-vpc"
  }
}

resource "aws_subnet" "main" {
  for_each = local.subnets

  vpc_id            = aws_vpc.main.id
  availability_zone = each.value.zone
  cidr_block        = each.value.cidr

  tags = {
    Name = "student-platform-${replace(each.key, "_", "-")}"
  }
}
