-- *********************************************************
-- schemas_sqlserver.sql — SQL Server table definitions
-- Package: epebdmc
-- FUTURE: uncomment and adapt when migrating from SQLite
-- *********************************************************

-- NOTE: Key differences from SQLite version:
--   AUTOINCREMENT     -> IDENTITY(1,1)
--   TEXT              -> NVARCHAR(500) or appropriate size
--   REAL              -> DECIMAL(18,2) or FLOAT
--   "IF NOT EXISTS"   -> check with IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'x')

/*

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'etl_log')
CREATE TABLE etl_log (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    source      NVARCHAR(200) NOT NULL,
    file_name   NVARCHAR(500),
    rows_in     INT,
    rows_out    INT,
    started_at  DATETIME NOT NULL,
    finished_at DATETIME,
    status      NVARCHAR(50) DEFAULT 'running'
);

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'raw_data')
CREATE TABLE raw_data (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    source      NVARCHAR(200) NOT NULL,
    loaded_at   DATETIME NOT NULL,
    row_count   INT
);

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'treated_data')
CREATE TABLE treated_data (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    source      NVARCHAR(200),
    key         NVARCHAR(200),
    value       NVARCHAR(MAX),
    treated_at  DATETIME
);

*/
