# Cloud Docs

GitHub 이슈에서 추적하고, 상세 내용은 여기에 문서화합니다.

## 구조

```
docs/
├── postmortem/        사고/장애 분석 보고서 (서비스 영향이 있는 인시던트)
├── troubleshooting/   기술 문제 해결 기록 (개별 컴포넌트 이슈)
├── architecture/      설계 및 구축 기록 (아키텍처, 인프라 구성)
└── runbook/           운영 절차서 (배포, 롤백, 크레덴셜 회전 등)
```

## 규칙

- **파일명**: `{이슈번호}-{kebab-case-설명}.md` (예: `079-db-credential-leak.md`)
- **이슈 없는 문서**: 절차서 등은 번호 없이 `{kebab-case-설명}.md`
- **양방향 링크**: 이슈에서 docs 링크, docs 상단에 이슈 링크
- **모든 이슈에 문서를 만들 필요 없음** — 이슈 본문으로 충분하면 이슈만으로 관리

## 문서 상단 형식

```markdown
# 제목

> 관련 이슈: [#번호](https://github.com/100-hours-a-week/13-team-project-cloud/issues/번호)
> 날짜: YYYY-MM-DD
> 작성자:

---
```
