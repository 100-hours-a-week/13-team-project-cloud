variable "project"     { type = string }
variable "environment" { type = string }
variable "common_tags" { type = map(string) }
variable "region"      { type = string }
variable "account_id"  { type = string }
variable "ec2_role_id" { type = string }

# =============================================================================
# Spring Boot 파라미터 목록
# 모든 환경에서 공통으로 사용. prefix는 모듈 내부에서 자동 구성.
# 환경별로 추가가 필요하면 environments/{env}/main.tf에서 merge()로 확장.
# =============================================================================
variable "ssm_parameters" {
  type = map(object({
    type        = string
    description = string
  }))
  default = {
    # Database
    DB_URL      = { type = "String",       description = "PostgreSQL JDBC URL" }
    DB_USERNAME = { type = "String",       description = "PostgreSQL 사용자명" }
    DB_PASSWORD = { type = "SecureString", description = "PostgreSQL 비밀번호" }

    # Redis
    REDIS_HOST     = { type = "String",       description = "Redis 호스트" }
    REDIS_PORT     = { type = "String",       description = "Redis 포트" }
    REDIS_PASSWORD = { type = "SecureString", description = "Redis 비밀번호" }

    # JWT
    JWT_SECRET                      = { type = "SecureString", description = "JWT 시크릿 키" }
    JWT_ISSUER                      = { type = "String",       description = "JWT 발급자" }
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES = { type = "String",       description = "JWT 액세스 토큰 만료(분)" }
    JWT_COOKIE_NAME                 = { type = "String",       description = "JWT 쿠키 이름" }
    JWT_COOKIE_SAME_SITE            = { type = "String",       description = "JWT SameSite 설정" }
    JWT_COOKIE_SECURE               = { type = "String",       description = "JWT Secure 플래그" }
    JWT_REFRESH_COOKIE_NAME         = { type = "String",       description = "리프레시 쿠키 이름" }
    JWT_REFRESH_TOKEN_EXPIRE_DAYS   = { type = "String",       description = "리프레시 토큰 만료(일)" }

    # Kakao OAuth
    KAKAO_CLIENT_ID             = { type = "String",       description = "카카오 클라이언트 ID" }
    KAKAO_CLIENT_SECRET         = { type = "SecureString", description = "카카오 클라이언트 시크릿" }
    KAKAO_ADMIN_KEY             = { type = "SecureString", description = "카카오 어드민 키" }
    KAKAO_REDIRECT_URI          = { type = "String",       description = "카카오 리다이렉트 URI" }
    KAKAO_FRONTEND_REDIRECT_URL = { type = "String",       description = "프론트 리다이렉트 URL" }
    KAKAO_UNLINK_URL            = { type = "String",       description = "카카오 연결끊기 URL" }

    # CSRF
    CSRF_COOKIE_DOMAIN = { type = "String", description = "CSRF 쿠키 도메인" }

    # AI 추천 서비스
    AI_RECOMMENDATION_BASE_URL = { type = "String", description = "AI 추천 서비스 베이스 URL" }

    # S3
    AWS_REGION            = { type = "String", description = "AWS 리전" }
    APP_S3_BUCKET         = { type = "String", description = "영수증 S3 버킷 이름" }
    APP_S3_RECEIPT_PREFIX = { type = "String", description = "영수증 S3 경로 prefix" }

    # 채팅 이미지
    CHAT_IMAGE_BUCKET                  = { type = "String", description = "채팅 이미지 S3 버킷" }
    CHAT_IMAGE_ALLOWED_CONTENT_TYPES   = { type = "String", description = "허용 Content-Type 목록" }
    CHAT_IMAGE_MAX_FILE_SIZE_BYTES     = { type = "String", description = "최대 파일 크기 (bytes)" }
    CHAT_IMAGE_PRESIGN_EXPIRES_SECONDS = { type = "String", description = "Presigned URL 유효시간 (초)" }
    CHAT_IMAGE_PUBLIC_BASE_URL         = { type = "String", description = "채팅 이미지 공개 URL base" }

    # DB 마이그레이션
    FLYWAY_ENABLED = { type = "String", description = "Flyway 마이그레이션 활성화 여부" }

    # OCR
    RUNPOD_OCR_BASE_URL = { type = "String", description = "RunPod OCR 서비스 베이스 URL" }

    # 배포 이미지 태그 (CD workflow에서 관리)
    IMAGE_TAG = { type = "String", description = "현재 배포된 Docker 이미지 태그" }
  }
}

# =============================================================================
# Recommend (FastAPI) 파라미터 목록
# =============================================================================
variable "ssm_recommend_parameters" {
  type = map(object({
    type        = string
    description = string
  }))
  default = {
    # PostgreSQL
    PG_HOST     = { type = "String",       description = "PostgreSQL 호스트" }
    PG_PORT     = { type = "String",       description = "PostgreSQL 포트" }
    PG_USER     = { type = "String",       description = "PostgreSQL 사용자명" }
    PG_PASSWORD = { type = "SecureString", description = "PostgreSQL 비밀번호" }
    PG_DB       = { type = "String",       description = "PostgreSQL 데이터베이스명" }

    # 배포 이미지 태그 (CD workflow에서 관리)
    IMAGE_TAG = { type = "String", description = "현재 배포된 Docker 이미지 태그" }
  }
}
