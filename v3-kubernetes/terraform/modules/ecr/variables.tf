variable "project"     { type = string }
variable "common_tags" { type = map(string) }

variable "service_names" {
  description = "ECR 레포지토리를 생성할 서비스 이름 목록"
  type        = list(string)
  default     = ["backend", "recommend"]
}
