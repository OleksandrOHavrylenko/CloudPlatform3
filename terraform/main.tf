terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws",
         version = "~> 5.93.0"
    }
  }
}

# --- VPC ---

resource "aws_vpc" "rds-postgres" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
      Name = "rds-postgres"
  }
}
# --- Public Subnet ---

resource "aws_subnet" "public-subnet-1"{
  vpc_id                  = aws_vpc.rds-postgres.id
  availability_zone       = "us-east-1a"
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-1"
  }
}

# --- Internet Gateway ---

resource "aws_internet_gateway" "rds-postgres-igw" {
  vpc_id = aws_vpc.rds-postgres.id
  tags = {
    Name = "rds-postgres-igw"
  }
}

# --- Public Route Table ---

resource "aws_route_table" "rds-postgres-rt-public" {
  vpc_id = aws_vpc.rds-postgres.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rds-postgres-igw.id
  }
  tags = {
    Name = "rds-postgres-rt-public"
  }
}

resource "aws_route_table_association" "rt-a-sn-1" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.rds-postgres-rt-public.id
}

# --- ECS Node SG ---

resource "aws_security_group" "rds-postgres-sg" {
  name_prefix = "webapi-ecs-node-sg-"
  vpc_id      = aws_vpc.rds-postgres.id

  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Postgres DB ---

  resource "aws_db_instance" "test-db" {
    allocated_storage      = 20
    storage_type           = "gp2"
    engine                 = "postgres"
    engine_version         = "17.2"
    instance_class         = "db.t4g.micro"
    identifier             = "postgres"
    username               = "postgres"
    password               = "postgres"
    publicly_accessible    = true
    parameter_group_name   = "default.postgres12"
    vpc_security_group_ids = [aws_security_group.rds-postgres-sg.id]
    skip_final_snapshot    = true

    tags = {
      Name = "postgres-db"
    }
  }

  output "rds_endpoint" {
    value = aws_db_instance.test-db.endpoint
  }