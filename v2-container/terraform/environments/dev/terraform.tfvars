region             = "ap-northeast-2"
vpc_cidr           = "10.1.0.0/16"
availability_zones = ["ap-northeast-2a", "ap-northeast-2b"]

public_subnet_cidrs       = ["10.1.4.0/24", "10.1.3.0/24"]
private_app_subnet_cidrs  = ["10.1.1.0/24"]
private_data_subnet_cidrs = ["10.1.2.0/24"]

ec2_ami_id        = "ami-0fa652388f45f21b5"
ec2_instance_type = "t4g.small"
ec2_key_name      = "tasteCompass-key"

v1_loki_ip = "10.1.0.251"
