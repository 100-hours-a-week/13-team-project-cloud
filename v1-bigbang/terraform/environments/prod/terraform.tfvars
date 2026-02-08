## VPC Configuration
vpc_cidr           = "10.0.0.0/16"
vpc_name           = "moyeoBab-prod"
availability_zones = ["ap-northeast-2a"]
vpc_subnet_cidrs   = ["10.0.0.0/24"]

vpc_tags = {
  Environment = "prod"
  Project     = "moyeoBab"
}

## EC2 Configuration
ec2_ami_id                      = "ami-0940de3547829dc20"
ec2_instance_type               = "t4g.small"
ec2_root_volume_size            = 50
ec2_root_volume_type            = "gp3"
ec2_associate_public_ip_address = true
ec2_key_name                    = "tasteCompass-key"
ec2_subnet_index                = 0
ec2_ssh_cidrs                   = ["0.0.0.0/0"]
ec2_http_cidrs                  = ["0.0.0.0/0"]
ec2_wireguard_cidrs             = ["0.0.0.0/0"]
ec2_private_ip                  = "10.0.0.161"
