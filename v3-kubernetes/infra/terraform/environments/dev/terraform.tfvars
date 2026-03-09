availability_zones = ["ap-northeast-2a", "ap-northeast-2b"]
k8s_subnet_cidrs   = ["10.1.10.0/24", "10.1.20.0/24"]

ec2_ami_id = "ami-0fa652388f45f21b5"

# K8s API Server 접근 허용 CIDR (관리자 IP, Bastion 등)
# admin_cidr_blocks = ["x.x.x.x/32"]
