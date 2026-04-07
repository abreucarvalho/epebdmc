-- ************************************************************
-- schemas_sqlite.sql — SQLite table definitions
-- Package: epebdmc
-- ************************************************************

-- ************************************************************
-- ETL METADATA
-- ************************************************************

CREATE TABLE IF NOT EXISTS etlLog (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    source      TEXT NOT NULL,
    fileName    TEXT,
    rowsIn      INTEGER,
    rowsOut     INTEGER,
    startedAt   TEXT NOT NULL,
    finishedAt  TEXT,
    status      TEXT DEFAULT 'running'
);

-- ************************************************************
-- DIMENSION TABLES
-- ************************************************************

CREATE TABLE IF NOT EXISTS dimUf (
    ufId            INTEGER PRIMARY KEY,
    ufCode          TEXT NOT NULL,
    ufName          TEXT NOT NULL,
    regionName      TEXT NOT NULL,
    isBrasilTotal   INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS dimGasType (
    gasId           INTEGER PRIMARY KEY,
    gasName         TEXT NOT NULL,
    gasFormula      TEXT NOT NULL,
    gasUnit         TEXT NOT NULL DEFAULT 'kt',
    isEquivalent    INTEGER DEFAULT 0,
    gwpAr5          REAL
);

CREATE TABLE IF NOT EXISTS dimSector (
    sectorId        INTEGER PRIMARY KEY,
    sectorName      TEXT NOT NULL,
    sectorNamePt    TEXT NOT NULL,
    ipccCategory    TEXT,
    isTotalSector   INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS dimYear (
    yearId          INTEGER PRIMARY KEY,
    inventoryPeriod TEXT NOT NULL
);

-- ************************************************************
-- FACT TABLE
-- ************************************************************

CREATE TABLE IF NOT EXISTS factEmissions (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ufId            INTEGER NOT NULL,
    sectorId        INTEGER NOT NULL,
    gasId           INTEGER NOT NULL,
    yearId          INTEGER NOT NULL,
    emissionKt      REAL,
    FOREIGN KEY (ufId)     REFERENCES dimUf(ufId),
    FOREIGN KEY (sectorId) REFERENCES dimSector(sectorId),
    FOREIGN KEY (gasId)    REFERENCES dimGasType(gasId),
    FOREIGN KEY (yearId)   REFERENCES dimYear(yearId)
);

-- ************************************************************
-- SEED DATA: dimUf
-- ************************************************************

INSERT OR IGNORE INTO dimUf (ufId, ufCode, ufName, regionName, isBrasilTotal) VALUES
    (11, 'RO', 'Rondônia',             'Norte',        0),
    (12, 'AC', 'Acre',                 'Norte',        0),
    (13, 'AM', 'Amazonas',             'Norte',        0),
    (14, 'RR', 'Roraima',              'Norte',        0),
    (15, 'PA', 'Pará',                 'Norte',        0),
    (16, 'AP', 'Amapá',                'Norte',        0),
    (17, 'TO', 'Tocantins',            'Norte',        0),
    (21, 'MA', 'Maranhão',             'Nordeste',     0),
    (22, 'PI', 'Piauí',                'Nordeste',     0),
    (23, 'CE', 'Ceará',                'Nordeste',     0),
    (24, 'RN', 'Rio Grande do Norte',  'Nordeste',     0),
    (25, 'PB', 'Paraíba',              'Nordeste',     0),
    (26, 'PE', 'Pernambuco',           'Nordeste',     0),
    (27, 'AL', 'Alagoas',              'Nordeste',     0),
    (28, 'SE', 'Sergipe',              'Nordeste',     0),
    (29, 'BA', 'Bahia',                'Nordeste',     0),
    (31, 'MG', 'Minas Gerais',         'Sudeste',      0),
    (32, 'ES', 'Espírito Santo',       'Sudeste',      0),
    (33, 'RJ', 'Rio de Janeiro',       'Sudeste',      0),
    (35, 'SP', 'São Paulo',            'Sudeste',      0),
    (41, 'PR', 'Paraná',               'Sul',          0),
    (42, 'SC', 'Santa Catarina',       'Sul',          0),
    (43, 'RS', 'Rio Grande do Sul',    'Sul',          0),
    (50, 'MS', 'Mato Grosso do Sul',   'Centro-Oeste', 0),
    (51, 'MT', 'Mato Grosso',          'Centro-Oeste', 0),
    (52, 'GO', 'Goiás',                'Centro-Oeste', 0),
    (53, 'DF', 'Distrito Federal',     'Centro-Oeste', 0),
    (99, 'BR', 'Brasil',               'Brasil',       1);

-- ************************************************************
-- SEED DATA: dimGasType
-- ************************************************************

INSERT OR IGNORE INTO dimGasType (gasId, gasName, gasFormula, gasUnit, isEquivalent, gwpAr5) VALUES
    (1, 'CO2 eq', 'CO₂ eq', 'kt',        1, NULL),
    (2, 'CO2',    'CO₂',    'kt',        0, 1.0),
    (3, 'CH4',    'CH₄',    'kt',        0, 28.0),
    (4, 'N2O',    'N₂O',    'kt',        0, 265.0),
    (5, 'HFCs',   'HFCs',   'kt CO₂ eq', 1, NULL),
    (6, 'PFCs',   'PFCs',   'kt CO₂ eq', 1, NULL),
    (7, 'SF6',    'SF₆',    'kt CO₂ eq', 1, NULL);

-- ************************************************************
-- SEED DATA: dimSector
-- ************************************************************

INSERT OR IGNORE INTO dimSector (sectorId, sectorName, sectorNamePt, ipccCategory, isTotalSector) VALUES
    (1, 'Energy',        'Energia',      '1',    0),
    (2, 'IPPU',          'IPPU',         '2',    0),
    (3, 'Agriculture',   'Agropecuária', '3',    0),
    (4, 'LULUCF',        'LULUCF',       '3B/4', 0),
    (5, 'Waste',         'Resíduos',     '5',    0),
    (6, 'Total',         'Total Brasil', NULL,   1);

