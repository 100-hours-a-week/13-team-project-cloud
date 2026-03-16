# 모여밥 Cloud

모여밥 서비스의 클라우드 인프라 및 운영 관리 레포지토리.

## 아키텍처 버전

| 버전 | 디렉토리 | 아키텍처 | 상태 |
|------|----------|----------|------|
| v1 | [`v1-bigbang/`](v1-bigbang/) | 단일 EC2 + Nginx + 직접 배포 | 전환 완료 (v1 -> v2) |
| v2 | [`v2-container/`](v2-container/) | Docker 컨테이너화 | **운영 중** |
| v3 | [`v3-kubernetes/`](v3-kubernetes/) | Kubernetes 오케스트레이션 | 준비 중 |

## 문서 위치

공식 문서는 [`docs/`](docs/) 아래에서 관리한다.

- Kubernetes 최종 설계 본문: [`docs/kubernetes/K8S-001-final-design.md`](docs/kubernetes/K8S-001-final-design.md)
- 개별 기술 선택 근거: [`docs/architecture/`](docs/architecture/)
- 사고 대응 및 운영 기록: [`docs/incidents/`](docs/incidents/), [`docs/operations/`](docs/operations/)