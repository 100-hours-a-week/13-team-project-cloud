/**
 * 카나리 마이그레이션 부하테스트 (총 10분, ALB weighted routing)
 *
 * Phase 1 (0~ 3분) : v1=100, v2=  0  — 기준선
 * Phase 2 (3~ 6분) : v1= 50, v2= 50  — run-canary.sh이 자동 전환
 * Phase 3 (6~10분) : v1=  0, v2=100  — run-canary.sh이 자동 전환
 *
 * 실행 방법: run-canary.sh 를 통해 실행 (직접 실행 X)
 *   ./v2-container/tests/canary/run-canary.sh
 *
 * 가중치 전환은 run-canary.sh 가 ALB modify-listener 로 자동 처리.
 * 이 스크립트는 부하만 발생시킨다.
 */

import http from "k6/http";
import { check, sleep, group } from "k6";
import { Rate, Trend } from "k6/metrics";
import {
  BASE_URL,
  TEST_CSRF_TOKEN,
} from "../lib/config.js";

// ─────────────────────────────────────────────────────────────
// 가중치 전환은 run-canary.sh 가 ALB modify-listener 로 자동 처리.
// 이 스크립트는 트래픽 부하만 발생시킨다.
// ─────────────────────────────────────────────────────────────

// 커스텀 메트릭
const errorRate = new Rate("canary_errors");
const pingDuration = new Trend("ping_duration");
const meetingListDuration = new Trend("meeting_list_duration");
const meetingCreateDuration = new Trend("meeting_create_duration");

// VU별 토큰 상태 (VU 전역)
// VU마다 고정 memberId로 기존 개발 계정에서 토큰 발급 — 계정 생성 불필요
// memberId 범위: 1000850 ~ 1000950 (101개), 50 VU에 순환 할당
const MEMBER_ID_START = 1000850;
const MEMBER_ID_COUNT = 101; // 1000850 ~ 1000950
let vuToken = null;

function refreshedHeaders() {
  if (vuToken === null) {
    const memberId = MEMBER_ID_START + ((__VU - 1) % MEMBER_ID_COUNT);
    let attempts = 0;
    while (vuToken === null && attempts < 3) {
      attempts++;
      const res = http.get(`${BASE_URL}/api/dev/auth/access/member/${memberId}`, {
        tags: { name: "token_init" },
      });
      if (res.status === 200 && res.cookies.access_token) {
        vuToken = res.cookies.access_token[0].value;
      } else {
        sleep(0.5 * attempts);
      }
    }
  }
  return {
    "Content-Type": "application/json",
    Cookie: `access_token=${vuToken}; csrf_token=${TEST_CSRF_TOKEN}`,
    "X-CSRF-Token": TEST_CSRF_TOKEN,
  };
}

// ─────────────────────────────────────────────────────────────
// 옵션
// ─────────────────────────────────────────────────────────────
export const options = {
  // ALB 방식: DNS는 항상 ALB 고정 IP → 라우팅은 ALB 내부에서 처리
  // noConnectionReuse / dns 설정 불필요 (Route53 weighted routing 시대의 잔재 제거)
  scenarios: {
    canary_constant_load: {
      executor: "constant-vus",
      vus: 50,
      duration: "10m",
    },
  },
  thresholds: {
    // 비즈니스 로직 에러율 — 전환 순간 포함 0.5% 미만
    // (token_init 재시도 잡음이 없는 순수 비즈니스 지표)
    canary_errors: ["rate<0.005"],
    // 레이턴시 — 전환 순간 여유 허용
    http_req_duration: ["p(95)<1000", "p(99)<2000"],
    // http_req_failed: token_init 재시도 실패가 포함돼 잘못 판정됨 → canary_errors로 대체
    // token_init 요청은 VU 시작 시점에 /access/new 실패 재시도가 http_req_failed 에 누적됨
    "http_req_failed{name:token_init}": [],   // 별도 추적 (통과 기준 없음, Grafana 확인용)
  },
};

// ─────────────────────────────────────────────────────────────
// Setup
// ─────────────────────────────────────────────────────────────
export function setup() {
  console.log("");
  console.log("═".repeat(62));
  console.log("  카나리 마이그레이션 테스트  (총 10분, 50 VU)");
  console.log("═".repeat(62));
  console.log("  Phase 1 ( 0 ~  3min) : v1=100, v2=  0  ← 지금 시작");
  console.log("  Phase 2 ( 3 ~  6min) : v1= 50, v2= 50  ← run-canary.sh 자동 전환");
  console.log("  Phase 3 ( 6 ~ 10min) : v1=  0, v2=100  ← run-canary.sh 자동 전환");
  console.log("═".repeat(62));
  console.log("  가중치 전환: ALB modify-listener (run-canary.sh 자동 처리)");
  console.log("  모니터링:   http://10.1.0.251:3000/d/v1-v2-migration");
  console.log("═".repeat(62));
  console.log("");

  return { startTime: Date.now() };
}

// ─────────────────────────────────────────────────────────────
// 메인 VU 루프
// ─────────────────────────────────────────────────────────────
function futureDateTime(offsetHours) {
  const d = new Date(Date.now() + offsetHours * 3600 * 1000);
  return d.toISOString().slice(0, 19); // "2026-02-21T12:00:00"
}

export default function (data) {
  const headers = refreshedHeaders();

  // 1. 헬스체크 (인증 불필요 — 가장 빠른 생사 확인)
  group("ping", () => {
    const res = http.get(`${BASE_URL}/api/ping`, {
      tags: { name: "ping" },
    });
    const ok = check(res, {
      "ping 200": (r) => r.status === 200,
      "ping < 500ms": (r) => r.timings.duration < 500,
    });
    errorRate.add(!ok);
    pingDuration.add(res.timings.duration);
  });

  sleep(0.5);

  // 2. 모임 목록 조회
  group("meeting_list", () => {
    const res = http.get(`${BASE_URL}/api/v1/meetings`, {
      headers: headers,
      tags: { name: "meeting_list" },
    });
    const ok = check(res, {
      "meetings 200": (r) => r.status === 200,
      "meetings < 800ms": (r) => r.timings.duration < 800,
    });
    errorRate.add(!ok);
    meetingListDuration.add(res.timings.duration);

    // 3. 모임 상세 조회 (목록에서 랜덤 선택)
    if (res.status === 200) {
      try {
        const body = res.json();
        const meetings = body.data || body;
        if (Array.isArray(meetings) && meetings.length > 0) {
          const m = meetings[Math.floor(Math.random() * Math.min(meetings.length, 5))];
          const id = m.meetingId || m.id;

          const detailRes = http.get(`${BASE_URL}/api/v1/meetings/${id}`, {
            headers: headers,
            tags: { name: "meeting_detail" },
          });
          const detailOk = check(detailRes, {
            "meeting detail 200": (r) => r.status === 200,
            "meeting detail < 800ms": (r) => r.timings.duration < 800,
          });
          errorRate.add(!detailOk);
        }
      } catch (_) {}
    }
  });

  sleep(0.5);

  // 4. 모임 생성 (5번 중 1번 — 과도한 데이터 생성 방지)
  if (__ITER % 5 === 0) {
    group("meeting_create", () => {
      const payload = JSON.stringify({
        title: `k6test${__VU}`,
        scheduledAt: futureDateTime(24),
        locationAddress: "경기 성남시 분당구 판교역로 166",
        locationLat: 37.3952,
        locationLng: 127.1109,
        targetHeadcount: 4,
        searchRadiusM: 500,
        voteDeadlineAt: futureDateTime(12),
        exceptMeat: false,
        exceptBar: false,
        swipeCount: 5,
        quickMeeting: false,
      });
      const res = http.post(`${BASE_URL}/api/v1/meetings`, payload, {
        headers: headers,
        tags: { name: "meeting_create" },
      });
      const ok = check(res, {
        "meeting create 201": (r) => r.status === 201,
        "meeting create < 1000ms": (r) => r.timings.duration < 1000,
      });
      errorRate.add(!ok);
      meetingCreateDuration.add(res.timings.duration);
    });
  }

  sleep(1);
}

// ─────────────────────────────────────────────────────────────
// Teardown
// ─────────────────────────────────────────────────────────────
export function teardown(data) {
  const elapsed = ((Date.now() - data.startTime) / 1000 / 60).toFixed(1);
  console.log("");
  console.log("═".repeat(62));
  console.log(`  테스트 완료: ${elapsed}분`);
  console.log("  Grafana: http://10.1.0.251:3000/d/v1-v2-migration");
  console.log("═".repeat(62));
  console.log("");
}
