monitoring_name                        = "moyeoBab-dev-monitoring"
monitoring_ami_id                      = "ami-073145d4c2fd2462b"
monitoring_instance_type               = "t4g.small"
monitoring_root_volume_size            = 50
monitoring_root_volume_type            = "gp3"
monitoring_associate_public_ip_address = true
monitoring_key_name                    = "tasteCompass-key"
monitoring_subnet_index                = 0
monitoring_ssh_cidrs                   = ["0.0.0.0/0"]
monitoring_loki_cidrs                  = ["10.1.0.0/16"]

monitoring_tags = {
  Environment = "dev"
  Project     = "moyeoBab"
}
