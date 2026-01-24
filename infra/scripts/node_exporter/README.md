# Node Exporter

## Systemd 등록

1) 바이너리 경로 확인

```bash
command -v node_exporter
```

2) 사용자 생성

```bash
sudo useradd --no-create-home --shell /usr/sbin/nologin node_exporter || true
```

3) 서비스 유닛 생성

아래 명령으로 유닛 파일을 생성.

```bash
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'EOF'
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
```

`ExecStart`는 `command -v node_exporter` 결과에 맞춰 수정.

4) 등록/실행

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl status node_exporter --no-pager
```

5) 동작 확인

```bash
curl -s http://localhost:9100/metrics | head
```
