# PostgreSQL User DDL

```sql
CREATE ROLE app_user WITH LOGIN PASSWORD 'change_me';
CREATE DATABASE app_db OWNER app_user;
-- GRANT ALL PRIVILEGES ON DATABASE app_db TO app_user;
-- ALTER ROLE app_user SET search_path TO public;
```
