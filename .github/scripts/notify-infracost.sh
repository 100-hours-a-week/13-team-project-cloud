#!/usr/bin/env bash
# Usage: notify-infracost.sh <env> <discord_color>
set -euo pipefail

ENV=$1
COLOR=$2

TOTAL=$(jq -r '.totalMonthlyCost // "0"' /tmp/infracost.json)
COUNT=$(jq '[.projects[].breakdown.resources[]] | length' /tmp/infracost.json)

jq -n \
  --slurpfile data /tmp/infracost.json \
  --arg env      "$ENV" \
  --arg total    "$TOTAL" \
  --arg count    "$COUNT" \
  --arg pr_title "$PR_TITLE" \
  --arg pr_num   "$PR_NUM" \
  --arg run_url  "$RUN_URL" \
  --arg color    "$COLOR" '

  # 비용 있는 리소스만 추출
  [$data[0].projects[].breakdown.resources[] |
    select(.monthlyCost != null and (.monthlyCost | tonumber) > 0)
  ] as $resources |

  # 카테고리 분류
  def categorize:
    if   (.name | test("aws_instance"))    then "🖥  Compute"
    elif (.name | test("aws_nat_gateway")) then "🌐  Networking"
    elif (.name | test("aws_lb"))          then "🌐  Networking"
    elif (.name | test("aws_route53"))     then "📋  기타"
    elif (.name | test("aws_cloudfront"))  then "📋  기타"
    else                                        "📋  기타"
    end;

  # 카테고리별 그룹핑
  (reduce $resources[] as $r (
    {};
    .[$r | categorize] += [$r]
  )) as $groups |

  # 카테고리 소계
  def cat_total(cat):
    ([$groups[cat]? // [] | .[] | .monthlyCost | tonumber] | add // 0) * 100 | round / 100 | tostring;

  # 리소스 이름 단축 (마지막 세그먼트, 언더스코어→하이픈)
  def short_name: .name | split(".") | last | gsub("_"; "-");

  # 카테고리 섹션 포맷
  def section(cat):
    if ($groups[cat] | length) > 0 then
      "\n" + cat + "  $" + cat_total(cat) + "/월\n" +
      ([$groups[cat][] | "  ├ " + short_name + "  $" + .monthlyCost] | join("\n"))
    else "" end;

  # 단일 embed
  {
    embeds: [{
      title: ("💰 [" + ($env | ascii_upcase) + "] 월 예상 비용  $" + $total + "/월"),
      description: (
        "**PR #" + $pr_num + "** — " + $pr_title + "\n" +
        "[Actions 로그 →](" + $run_url + ")\n" +
        "```\n" +
        section("🖥  Compute") +
        section("🌐  Networking") +
        section("📋  기타") +
        "\n\n합계  $" + $total + "/월  (" + $count + "개 리소스)\n" +
        "```"
      ),
      color: ($color | tonumber),
      footer: { text: ("Infracost · terraform/environments/" + $env) }
    }]
  }
' | curl -sS -X POST "$WEBHOOK" \
    -H "Content-Type: application/json" \
    -d @-
