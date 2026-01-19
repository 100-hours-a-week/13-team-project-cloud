# Infrastructure

맛침반 클라우드 인프라를 위한 Terraform 구성입니다.

## 디렉토리 구조

```
infra/terraform/
├── environments/
│   └── dev/                 # 개발 환경
│       ├── main.tf          # 모듈 호출
│       ├── variables.tf     # 입력 변수 정의
│       ├── terraform.tfvars # 환경별 값
│       ├── provider.tf      # AWS provider 설정
│       └── .terraform.lock.hcl
└── modules/
    └── vpc/                 # VPC 모듈
        ├── main.tf          # 리소스 정의
        ├── variables.tf     # 모듈 입력
        └── outputs.tf       # 모듈 출력
```

## VPC 리소스

VPC 모듈(`modules/vpc`)은 다음 리소스를 생성합니다.

| 리소스                    | 설명                                             |
| ------------------------- | ------------------------------------------------ |
| `aws_vpc`                 | 기본 VPC 생성                                   |
| `aws_subnet`              | 지정한 AZ에 서브넷 생성                          |
| `aws_internet_gateway`    | VPC에 연결된 인터넷 게이트웨이                   |
| `aws_default_route_table` | 기본 라우팅 테이블에 0.0.0.0/0 → IGW 라우트 추가 |

**Note:** `aws_default_route_table`로 VPC 생성 시 자동으로 만들어지는 기본 라우팅 테이블을 관리합니다. 별도의 커스텀 라우팅 테이블을 만들지 않습니다.

## 환경 설정

`terraform.tfvars`에서 환경별 값을 설정합니다. 형식은 `terraform.tfvars.example` 참고.

## 사용 방법

### 사전 요구사항

- Terraform >= 1.14.3
- AWS CLI 자격 증명 설정 완료

### 인프라 적용

```bash
cd infra/terraform/environments/dev

# 초기화 (최초 또는 모듈 변경 후)
terraform init

# 변경사항 확인
terraform plan

# 적용
terraform apply
```

### 인프라 삭제

```bash
cd infra/terraform/environments/dev
terraform destroy
```

## 모듈 출력

| Output                | 설명                 |
| --------------------- | -------------------- |
| `vpc_id`              | 생성된 VPC ID        |
| `subnet_ids`          | 서브넷 ID 목록       |
| `internet_gateway_id` | 인터넷 게이트웨이 ID |
