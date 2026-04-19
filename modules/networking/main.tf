# ── VPC ──────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project}-vpc" }
}

# ── Public Subnets (ALB requires at least 2 AZs) ─────────

resource "aws_subnet" "public" {
  count = length(var.az_list)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1) # 10.0.1.0/24, 10.0.2.0/24
  availability_zone       = var.az_list[count.index]
  map_public_ip_on_launch = true # Required for ECS tasks to pull from ECR without NAT GW

  tags = { Name = "${var.project}-public-${count.index + 1}" }
}

# ── Internet Gateway ──────────────────────────────────────

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project}-igw" }
}

# ── Route Table (Public -> IGW) ───────────────────────────

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ── Security Groups ───────────────────────────────────────

# ALB: allow inbound 80/443 from internet
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "ALB - allow inbound from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound to VPC only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.project}-alb-sg" }
}

# ECS Task: inbound from VPC only, outbound to all
# (Public subnet + SG strategy instead of NAT GW)
resource "aws_security_group" "ecs" {
  name        = "${var.project}-ecs-sg"
  description = "ECS Task - inbound from VPC only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow all inbound from VPC (ALB to ECS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound - for ECR pull and external APIs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-ecs-sg" }
}

# RDS: inbound/outbound from VPC only
resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "RDS - allow VPC internal traffic only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL from VPC only"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Outbound to VPC only"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.project}-rds-sg" }
}
