# RDS security group allows MySQL traffic ONLY from the EC2 SG
resource "aws_security_group" "rds_mysql" {
  name        = "${var.project_prefix}-rds-mysql"
  description = "Allow MySQL from EC2 SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "MySQL from EC2"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2_ssh.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "${var.project_prefix}-rds-mysql" }
}

resource "aws_db_subnet_group" "db" {
  name       = "${var.project_prefix}-db-subnets"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  tags = { Name = "${var.project_prefix}-db-subnets" }
}

resource "aws_db_instance" "mysql" {
  identifier             = "${var.project_prefix}-mysql"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.rds_mysql.id]
  multi_az               = false
  publicly_accessible    = false  # Secure by default for Terraform module
  skip_final_snapshot    = true

  # Ensure we don't try to create before subnets/sg are ready
  depends_on = [aws_db_subnet_group.db, aws_security_group.rds_mysql]
}

output "rds_endpoint" {
  value = aws_db_instance.mysql.endpoint
}
