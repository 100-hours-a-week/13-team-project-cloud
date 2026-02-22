// Base URL (dev 환경 고정)
export const BASE_URL = "https://api.dev.moyeobab.com";

// 테스트용 Access Token (테스트 전에 갱신 필요, 15분 만료)
// GET /api/dev/auth/access/new 호출 후 발급받은 토큰으로 교체
export const TEST_ACCESS_TOKEN = "YOUR_JWT_TOKEN_HERE";

// 테스트용 CSRF Token
export const TEST_CSRF_TOKEN = "test-csrf-token-for-load-test";

// 공통 헤더
export function getHeaders() {
  return {
    "Content-Type": "application/json",
    "Cookie": `access_token=${TEST_ACCESS_TOKEN}; csrf_token=${TEST_CSRF_TOKEN}`,
    "X-CSRF-Token": TEST_CSRF_TOKEN,
  };
}

// 공통 임계값
export const THRESHOLDS = {
  http_req_duration: ["p(95)<500"],
  http_req_failed: ["rate<0.01"],
};
