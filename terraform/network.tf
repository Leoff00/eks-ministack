resource "aws_vpc" "eks" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "ministack-eks" }
}

resource "aws_internet_gateway" "eks" {
  vpc_id = aws_vpc.eks.id
  tags   = { Name = "ministack-eks" }
}


resource "aws_subnet" "public" {
  for_each                = { a = "10.20.1.0/24", b = "10.20.2.0/24", c = "10.20.3.0/24" }
  vpc_id                  = aws_vpc.eks.id
  cidr_block              = each.value
  availability_zone       = "us-east-1${each.key}"
  map_public_ip_on_launch = true
  tags = {
    Name                                  = "ministack-eks-${each.key}"
    "kubernetes.io/role/elb"              = "1"
    "kubernetes.io/cluster/ministack-lab" = "shared"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks.id
  }
  tags = { Name = "ministack-eks-public" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
