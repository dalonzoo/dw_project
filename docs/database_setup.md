# Database Setup

This project uses PostgreSQL with PostGIS.

## 1. Verify PostgreSQL

In PowerShell:

```powershell
psql --version
```

If PowerShell cannot find `psql`, PostgreSQL may not be installed or its `bin` directory may not be in `PATH`.

Common Windows path:

```text
C:\Program Files\PostgreSQL\16\bin
```

## 2. Create The Database

Open `psql`, pgAdmin, or DBeaver connected to the default `postgres` database, then run:

```sql
CREATE DATABASE urban_night_mobility_dw;
```

## 3. Initialize Extensions And Schemas

Connect to `urban_night_mobility_dw`, then run:

```sql
\i sql/00_init_database.sql
```

If you are using DBeaver, open `sql/00_init_database.sql` and execute the whole script.

## 4. Expected Result In DBeaver

After refreshing the connection, you should see these schemas:

- `staging`
- `reconciled`
- `dw`
- `audit`

You should also be able to run:

```sql
SELECT PostGIS_Version();
```

This is a useful first live-demo proof: it shows the project is using a real DBMS plus spatial functionality.

## 5. Connection Values

Default local values are documented in `.env.example`.

Copy it to `.env` for local scripts:

```powershell
Copy-Item .env.example .env
```

Do not commit `.env`.
