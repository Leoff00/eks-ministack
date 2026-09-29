
resource "aws_security_group" "sg" {
  name        = "allow_tls"
  description = "Security group para acesso HTTPS"
  vpc_id      = aws_vpc.eks.id

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "allow_tls"
    Description = "Security group que permite HTTPS"
  }
}
