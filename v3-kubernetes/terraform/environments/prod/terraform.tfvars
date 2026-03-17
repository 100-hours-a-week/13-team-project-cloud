# dev와 동일 AMI (ECR credential provider 포함)
ec2_ami_id = "ami-04b47c7d72b84efef"

# K8s API Server 접근 허용 CIDR (관리자 IP, Bastion 등)
# admin_cidr_blocks = ["x.x.x.x/32"]

cp_instance_type = "t4g.medium"
wp_instance_type = "t4g.medium"
