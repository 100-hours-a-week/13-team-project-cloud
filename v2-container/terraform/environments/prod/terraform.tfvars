vpc_cidr           = "10.0.0.0/16"
availability_zones = ["ap-northeast-2a", "ap-northeast-2b"]

public_subnet_cidrs       = ["10.0.3.0/24", "10.0.4.0/24"]
private_app_subnet_cidrs  = ["10.0.1.0/24", "10.0.6.0/24"]
private_data_subnet_cidrs = ["10.0.2.0/24", "10.0.7.0/24"]

ec2_ami_id = "ami-0fa652388f45f21b5"

vpc_peering_id = "pcx-0fd722e5877d95009"

# prod-monitoring 배포 후 SG ID 입력
# monitoring_sg_id = "sg-xxxxxxxxx"
