resource "aws_vpc" "keycloak-vpc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    project        = "MBTA-Keycloak"
    Name           = "Keycloak-VPC" 
  }
}

resource "aws_internet_gateway" "keycloak-igw" {
  vpc_id = aws_vpc.keycloak-vpc.id

  tags = {
    project        = "MBTA-Keycloak"
    Name           = "Keycloak-IGW"
  }

}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.keycloak-vpc.id
  cidr_block              = element(var.public_subnets, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  count                   = length(var.public_subnets)
  map_public_ip_on_launch = true

  tags = {
    Name           = "keycloak-public-subnet-${count.index + 1}"
    project        = "MBTA-Keycloak"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.keycloak-vpc.id

  tags = {
    Name           = "keycloak-routing-table-public"
    project        = "MBTA-Keycloak"
  }
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.keycloak-igw.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.keycloak-vpc.id
  cidr_block              = element(var.private_subnets, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  count                   = length(var.private_subnets)

  tags = {
    Name           = "keycloak-private-subnet-${count.index + 1}"
    project        = "MBTA-Keycloak"
  }
}

resource "aws_nat_gateway" "public-nat" {
  allocation_id    = element(aws_eip.public-nat-eip.*.id, count.index)
  subnet_id        = element(aws_subnet.public.*.id, count.index)
  count            = length(var.public_subnets)

  tags = {
    Name           = "public-nat-${count.index + 1}"
    project        = "MBTA-Keycloak"
  }

  depends_on = [aws_internet_gateway.keycloak-igw]
}

resource "aws_eip" "public-nat-eip" {
  vpc = true
  count                     = length(var.public_subnets)
  depends_on                = [aws_internet_gateway.keycloak-igw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.keycloak-vpc.id
  count  = length(var.private_subnets)

  tags = {
    Name           = "keycloak-routing-table-private-${count.index + 1}"
    project        = "MBTA-Keycloak"
  }
}

resource "aws_route" "private" {
  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = element(aws_nat_gateway.public-nat.*.id, count.index)
  count                  = length(var.private_subnets)
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

