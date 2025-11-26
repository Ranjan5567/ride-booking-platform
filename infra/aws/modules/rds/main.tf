# RDS Module - Managed PostgreSQL database (requirement: cloud storage products - managed SQL)
# Stores all relational data: users, drivers, rides, payments

# Use default VPC subnet group for public access
# Comment out custom subnet group - will use AWS default instead
# resource "aws_db_subnet_group" "main" {
#   name       = "${var.db_name}-subnet-group"
#   subnet_ids = var.subnet_ids
#
#   tags = {
#     Name = "${var.db_name}-subnet-group"
#   }
# }

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "rds" {
  name        = "${var.db_name}-sg"
  description = "Security group for RDS"
  vpc_id      = data.aws_vpc.default.id  # Use default VPC instead

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow public access (for Query Editor)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.db_name}-sg"
  }
}

# RDS PostgreSQL Instance - managed database for all microservices
# All 4 backend services connect to this shared database
resource "aws_db_instance" "main" {
  identifier             = var.db_name
  engine                 = "postgres"
  engine_version         = "15.10"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_encrypted      = true
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  # db_subnet_group_name = aws_db_subnet_group.main.name  # Don't specify - use default
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true  # Allows connection from outside VPC (for port-forwarding)
  skip_final_snapshot    = true
  backup_retention_period = 7

  tags = {
    Name = var.db_name
  }
}

output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_name" {
  value = aws_db_instance.main.db_name
}

