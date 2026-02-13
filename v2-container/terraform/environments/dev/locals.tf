locals {
  project     = "moyeobab"
  environment = "dev"
  version     = "v2"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    Version     = local.version
    ManagedBy   = "terraform"
  }

  # 서비스별 태그 (Prometheus ec2_sd_configs 연동)
  service_tags = {
    api = {
      Tier        = "app"
      Service     = "backend"
      ServicePort = "8080"
      MetricsPath = "/actuator/prometheus"
    }
    recommend = {
      Tier        = "app"
      Service     = "recommend"
      ServicePort = "8000"
      MetricsPath = "/metrics"
    }
    postgresql = {
      Tier        = "data"
      Service     = "postgresql"
      ServicePort = "5432"
      MetricsPath = ""
    }
    redis = {
      Tier        = "data"
      Service     = "redis"
      ServicePort = "6379"
      MetricsPath = ""
    }
  }

  # GitHub Actions OIDC
  github_org   = "100-hours-a-week"
  github_repos = ["13-team-project-ai", "13-team-project-be"]

  oidc_subjects = flatten([
    for repo in local.github_repos : [
      "repo:${local.github_org}/${repo}:ref:refs/heads/develop",
      "repo:${local.github_org}/${repo}:environment:develop",
    ]
  ])

  # SSM Parameter Store — Spring Boot 환경변수
  ssm_prefix = "/${local.project}/spring/${local.environment}"

  ssm_parameters = {
    # Database
    DB_URL      = { type = "String", description = "PostgreSQL JDBC URL" }
    DB_USERNAME = { type = "String", description = "PostgreSQL 사용자명" }
    DB_PASSWORD = { type = "SecureString", description = "PostgreSQL 비밀번호" }

    # Redis
    REDIS_HOST     = { type = "String", description = "Redis 호스트" }
    REDIS_PORT     = { type = "String", description = "Redis 포트" }
    REDIS_PASSWORD = { type = "SecureString", description = "Redis 비밀번호" }

    # JWT
    JWT_SECRET                      = { type = "SecureString", description = "JWT 시크릿 키" }
    JWT_ISSUER                      = { type = "String", description = "JWT 발급자" }
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES = { type = "String", description = "JWT 액세스 토큰 만료(분)" }
    JWT_COOKIE_NAME                 = { type = "String", description = "JWT 쿠키 이름" }
    JWT_COOKIE_SAME_SITE            = { type = "String", description = "JWT SameSite 설정" }
    JWT_COOKIE_SECURE               = { type = "String", description = "JWT Secure 플래그" }
    JWT_REFRESH_COOKIE_NAME         = { type = "String", description = "리프레시 쿠키 이름" }
    JWT_REFRESH_TOKEN_EXPIRE_DAYS   = { type = "String", description = "리프레시 토큰 만료(일)" }

    # Kakao OAuth
    KAKAO_CLIENT_ID             = { type = "String", description = "카카오 클라이언트 ID" }
    KAKAO_CLIENT_SECRET         = { type = "SecureString", description = "카카오 클라이언트 시크릿" }
    KAKAO_ADMIN_KEY             = { type = "SecureString", description = "카카오 어드민 키" }
    KAKAO_REDIRECT_URI          = { type = "String", description = "카카오 리다이렉트 URI" }
    KAKAO_FRONTEND_REDIRECT_URL = { type = "String", description = "프론트 리다이렉트 URL" }
    KAKAO_UNLINK_URL            = { type = "String", description = "카카오 연결끊기 URL" }

    # CSRF
    CSRF_COOKIE_DOMAIN = { type = "String", description = "CSRF 쿠키 도메인" }
  }

  # SSM Parameter Store — Recommend (FastAPI) 환경변수
  ssm_recommend_prefix = "/${local.project}/recommend/${local.environment}"

  ssm_recommend_parameters = {
    PG_HOST     = { type = "String", description = "PostgreSQL 호스트" }
    PG_PORT     = { type = "String", description = "PostgreSQL 포트" }
    PG_USER     = { type = "String", description = "PostgreSQL 사용자명" }
    PG_PASSWORD = { type = "SecureString", description = "PostgreSQL 비밀번호" }
    PG_DB       = { type = "String", description = "PostgreSQL 데이터베이스명" }
  }
}
