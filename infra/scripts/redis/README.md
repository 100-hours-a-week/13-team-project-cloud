# Redis Commands

```bash
sudoedit /etc/redis/redis.conf
```

```text
requirepass your_strong_password
```

```bash
sudo systemctl restart redis-server
sudo systemctl status redis-server --no-pager
redis-cli -a 'your_strong_password' ping
```

```text
AUTH your_strong_password
PING
```
