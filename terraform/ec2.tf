# Key pair (TLS private key generated locally and uploaded public key to EC2)
resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "${var.project_prefix}-key"
  public_key = tls_private_key.ec2.public_key_openssh
}

# Save the private key to a local file for SSH
resource "local_file" "private_key_pem" {
  filename = "${path.module}/ec2_${var.project_prefix}.pem"
  content  = tls_private_key.ec2.private_key_pem
  file_permission = "0400"
}

resource "aws_instance" "web" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.ec2_ssh.id]
  key_name               = aws_key_pair.ec2_key.key_name
  associate_public_ip_address = true

  tags = {
    Name = "${var.project_prefix}-ec2"
  }
}

output "ec2_public_ip" {
  value = aws_instance.web.public_ip
}
