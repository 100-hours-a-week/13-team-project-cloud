resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = var.key_name
  associate_public_ip_address = var.associate_public_ip_address
  private_ip                  = var.private_ip

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = false
  }

  tags = merge(
    { Name = var.name },
    var.tags
  )
}

resource "aws_volume_attachment" "db" {
  device_name                    = var.db_device_name
  volume_id                      = var.db_volume_id
  instance_id                    = aws_instance.app.id
  stop_instance_before_detaching = true
}

resource "aws_eip_association" "app" {
  allocation_id       = var.eip_allocation_id
  instance_id         = aws_instance.app.id
  allow_reassociation = true
}
