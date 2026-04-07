-- *********************************************************
-- schemas_sqlserver.sql — SQL Server table definitions
-- Package: epebdmc
-- FUTURE: uncomment and adapt when migrating from SQLite
-- *********************************************************

/*

-- ETL METADATA
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'etlLog')
CREATE TABLE etlLog (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    source      NVARCHAR(200) NOT NULL,
    fileName    NVARCHAR(500),
    rowsIn      INT,
    rowsOut     INT,
    startedAt   DATETIME NOT NULL,
    finishedAt  DATETIME,
    status      NVARCHAR(50) DEFAULT 'running'
);

-- DIMENSION TABLES
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'dimUf')
CREATE TABLE dimUf (
    ufId            INT PRIMARY KEY,
    ufCode          NVARCHAR(2) NOT NULL,
    ufName          NVARCHAR(100) NOT NULL,
    regionName      NVARCHAR(50) NOT NULL,
    isBrasilTotal   BIT DEFAULT 0
);

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'dimGasType')
CREATE TABLE dimGasType (
    gasId           INT PRIMARY KEY,
    gasName         NVARCHAR(20) NOT NULL,
    gasFormula      NVARCHAR(20) NOT NULL,
    gasUnit         NVARCHAR(10) NOT NULL DEFAULT 'kt',
    isEquivalent    BIT DEFAULT 0,
    gwpAr5          FLOAT
);

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'dimYear')
CREATE TABLE dimYear (
    yearId          INT PRIMARY KEY,
    inventoryPeriod NVARCHAR(50) NOT NULL DEFAULT 'BTR1 (1990-2022)'
);

-- FACT TABLE
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'factEnergyEmissions')
CREATE TABLE factEnergyEmissions (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    ufId            INT NOT NULL,
    gasId           INT NOT NULL,
    yearId          INT NOT NULL,
    emissionKt      FLOAT,
    FOREIGN KEY (ufId)   REFERENCES dimUf(ufId),
    FOREIGN KEY (gasId)  REFERENCES dimGasType(gasId),
    FOREIGN KEY (yearId) REFERENCES dimYear(yearId)
);

-- SEED DATA: dimUf
INSERT INTO dimUf (ufId, ufCode, ufName, regionName, isBrasilTotal) VALUES
    (11, 'RO', N'Rondônia',             N'Norte',        0),
    (12, 'AC', N'Acre',                 N'Norte',        0),
    (13, 'AM', N'Amazonas',             N'Norte',        0),
    (14, 'RR', N'Roraima',              N'Norte',        0),
    (15, 'PA', N'Pará',                 N'Norte',        0),
    (16, 'AP', N'Amapá',                N'Norte',        0),
    (17, 'TO', N'Tocantins',            N'Norte',        0),
    (21, 'MA', N'Maranhão',             N'Nordeste',     0),
    (22, 'PI', N'Piauí',                N'Nordeste',     0),
    (23, 'CE', N'Ceará',                N'Nordeste',     0),
    (24, 'RN', N'Rio Grande do Norte',  N'Nordeste',     0),
    (25, 'PB', N'Paraíba',              N'Nordeste',     0),
    (26, 'PE', N'Pernambuco',           N'Nordeste',     0),
    (27, 'AL', N'Alagoas',              N'Nordeste',     0),
    (28, 'SE', N'Sergipe',              N'Nordeste',     0),
    (29, 'BA', N'Bahia',                N'Nordeste',     0),
    (31, 'MG', N'Minas Gerais',         N'Sudeste',      0),
    (32, 'ES', N'Espírito Santo',       N'Sudeste',      0),
    (33, 'RJ', N'Rio de Janeiro',       N'Sudeste',      0),
    (35, 'SP', N'São Paulo',            N'Sudeste',      0),
    (41, 'PR', N'Paraná',               N'Sul',          0),
    (42, 'SC', N'Santa Catarina',       N'Sul',          0),
    (43, 'RS', N'Rio Grande do Sul',    N'Sul',          0),
    (50, 'MS', N'Mato Grosso do Sul',   N'Centro-Oeste', 0),
    (51, 'MT', N'Mato Grosso',          N'Centro-Oeste', 0),
    (52, 'GO', N'Goiás',                N'Centro-Oeste', 0),
    (53, 'DF', N'Distrito Federal',     N'Centro-Oeste', 0),
    (99, 'BR', N'Brasil',               N'Brasil',       1);

-- SEED DATA: dimGasType
INSERT INTO dimGasType (gasId, gasName, gasFormula, gasUnit, isEquivalent, gwpAr5) VALUES
    (1, 'CO2 eq', N'CO₂ eq', 'kt', 1, NULL),
    (2, 'CO2',    N'CO₂',    'kt', 0, 1.0),
    (3, 'CH4',    N'CH₄',    'kt', 0, 28.0),
    (4, 'N2O',    N'N₂O',    'kt', 0, 265.0);

-- SEED DATA: dimYear (same as SQLite, just remove OR IGNORE)
INSERT INTO dimYear (yearId, inventoryPeriod) VALUES
    (1990, 'BTR1 (1990-2022)'), (1991, 'BTR1 (1990-2022)'),
    (1992, 'BTR1 (1990-2022)'), (1993, 'BTR1 (1990-2022)'),
    (1994, 'BTR1 (1990-2022)'), (1995, 'BTR1 (1990-2022)'),
    (1996, 'BTR1 (1990-2022)'), (1997, 'BTR1 (1990-2022)'),
    (1998, 'BTR1 (1990-2022)'), (1999, 'BTR1 (1990-2022)'),
    (2000, 'BTR1 (1990-2022)'), (2001, 'BTR1 (1990-2022)'),
    (2002, 'BTR1 (1990-2022)'), (2003, 'BTR1 (1990-2022)'),
    (2004, 'BTR1 (1990-2022)'), (2005, 'BTR1 (1990-2022)'),
    (2006, 'BTR1 (1990-2022)'), (2007, 'BTR1 (1990-2022)'),
    (2008, 'BTR1 (1990-2022)'), (2009, 'BTR1 (1990-2022)'),
    (2010, 'BTR1 (1990-2022)'), (2011, 'BTR1 (1990-2022)'),
    (2012, 'BTR1 (1990-2022)'), (2013, 'BTR1 (1990-2022)'),
    (2014, 'BTR1 (1990-2022)'), (2015, 'BTR1 (1990-2022)'),
    (2016, 'BTR1 (1990-2022)'), (2017, 'BTR1 (1990-2022)'),
    (2018, 'BTR1 (1990-2022)'), (2019, 'BTR1 (1990-2022)'),
    (2020, 'BTR1 (1990-2022)'), (2021, 'BTR1 (1990-2022)'),
    (2022, 'BTR1 (1990-2022)');

*/
