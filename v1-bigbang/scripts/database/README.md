# PostgreSQL 데이터 영구 보존 및 EBS 재연결 가이드

이 문서는 별도의 EBS 볼륨을 사용하여 PostgreSQL 데이터를 관리하는 절차를 설명합니다. 이 구성을 통해 Terraform으로 EC2 인스턴스를 삭제하거나 재생성하더라도 데이터베이스 데이터는 안전하게 보존됩니다.

## 1. 아키텍처 개요

1.  **인프라 (Terraform):**
    *   `lifecycle { prevent_destroy = true }` 설정이 적용된 EBS 볼륨을 생성합니다.
    *   이 볼륨을 EC2 인스턴스에 자동으로 연결(Attach)합니다. (예: `/dev/sdf` 또는 `/dev/nvme0n1`)
2.  **OS 레벨 (Script):**
    *   `migrate-postgres-data-dir.sh` 스크립트가 EBS 볼륨을 `/var/lib/postgresql/...` 경로에 마운트합니다.
    *   `/etc/fstab`을 설정하여 재부팅 시에도 자동으로 마운트되도록 합니다.

## 2. 작업 가이드

Terraform으로 EC2 인스턴스가 배포되고 볼륨이 연결된 후 다음 단계를 수행하십시오.

### 1단계: 디스크 연결 확인
EC2 인스턴스에 SSH로 접속하여 사용 가능한 블록 장치를 확인합니다.

```bash
lsblk
```

*   **마운트되지 않았고(MOUNTPOINT가 비어 있음)** 예상 크기(예: 20G)를 가진 볼륨을 찾습니다.
*   *참고:* Nitro 기반 인스턴스에서는 디바이스 이름이 `/dev/sdf` 대신 `/dev/nvme[0-9]n1` 형태로 보일 수 있습니다.

### 2단계: 기존 데이터 확인 (매우 중요)
마이그레이션 스크립트를 실행하기 전에, 볼륨에 데이터가 이미 있는지 **반드시** 확인해야 합니다.

```bash
lsblk -f <장치_이름>
# 예시: lsblk -f /dev/nvme0n1
```

| FSTYPE 출력값 | 상태 | 조치 방법 |
| :--- | :--- | :--- |
| **비어 있음 (Empty)** | 새 볼륨 (초기 상태) | `AUTO_FORMAT=1`을 사용하여 포맷 및 초기화 진행. |
| **`ext4` / `xfs`** | 기존 데이터 있음 (재연결) | **절대 포맷하지 마십시오.** 환경 변수 없이 스크립트만 실행. |

### 3단계: 마이그레이션 및 연결 실행
2단계에서 확인한 상태에 따라 알맞은 명령어를 실행하십시오.

**시나리오 A: 완전 새 볼륨 (최초 설정 시)**
```bash
# 디스크를 포맷하고 현재 기본 DB 데이터를 해당 볼륨으로 이동
sudo AUTO_FORMAT=1 infra/scripts/database/migrate-postgres-data-dir.sh /dev/nvme0n1
```

**시나리오 B: 기존 볼륨 (새 EC2에 재연결 시)**
```bash
# 기존 디스크를 마운트하고 그 안의 데이터를 그대로 사용. (포맷 X)
sudo infra/scripts/database/migrate-postgres-data-dir.sh /dev/nvme0n1
```

### 4단계: 검증
1.  **마운트 포인트 확인:**
    ```bash
    lsblk
    # 해당 장치의 MOUNTPOINT에 /var/lib/postgresql/... 경로가 표시되어야 합니다.
    ```
2.  **서비스 상태 확인:**
    ```bash
    systemctl status postgresql
    # 상태가 "active (running)"이어야 합니다.
    ```

## 3. 데이터베이스 초기화 (DDL)

```sql
CREATE ROLE app_user WITH LOGIN PASSWORD 'change_me';
CREATE DATABASE app_db OWNER app_user;
-- GRANT ALL PRIVILEGES ON DATABASE app_db TO app_user;
-- ALTER ROLE app_user SET search_path TO public;
```
