PRAGMA foreign_keys = ON;
-- ======================
-- MEMBERS
-- ======================
CREATE TABLE IF NOT EXISTS Members (
  member_id   INTEGER PRIMARY KEY,     -- Row Number from CSV (1..40)
  first_name  TEXT        NOT NULL,
  last_name   TEXT        NOT NULL,
  major       TEXT,
  join_date   TEXT                     -- 'YYYY-MM-DD'
);
-- ======================
-- PORTFOLIOS
-- ======================
CREATE TABLE IF NOT EXISTS Portfolios (
  portfolio_id   INTEGER PRIMARY KEY,  -- Row Number (1..60)
  member_id      INTEGER   NOT NULL,   -- FK -> Members
  portfolio_name TEXT      NOT NULL,
  created_date   TEXT,
  notes          TEXT,
  FOREIGN KEY (member_id) REFERENCES Members(member_id)
);
CREATE INDEX IF NOT EXISTS idx_portfolios_member_id
  ON Portfolios(member_id);
-- ======================
-- ASSETS
-- ======================
CREATE TABLE IF NOT EXISTS Assets (
  asset_id      INTEGER PRIMARY KEY,   -- Row Number (1..120)
  symbol        TEXT    NOT NULL UNIQUE,
  asset_type    TEXT    NOT NULL,      -- STOCK / CRYPTO / FUND
  market        TEXT    NOT NULL,      -- NASDAQ/NYSE/ETF/CRYPTO
  current_price REAL
);

-- ======================
-- TRADES
-- ======================
CREATE TABLE IF NOT EXISTS Trades (
  trade_id     INTEGER PRIMARY KEY,    -- Row Number (1..800)
  portfolio_id INTEGER  NOT NULL,      -- FK -> Portfolios
  asset_id     INTEGER  NOT NULL,      -- FK -> Assets
  trade_date   TEXT     NOT NULL,      -- 'YYYY-MM-DD'
  trade_type   TEXT     NOT NULL,      -- BUY or SELL
  quantity     REAL     NOT NULL,      -- ints in our CSV (REAL is OK)
  trade_price  REAL     NOT NULL,
  fee          REAL,                   -- may be NULL (~10%)
  notes        TEXT,
  FOREIGN KEY (portfolio_id) REFERENCES Portfolios(portfolio_id),
  FOREIGN KEY (asset_id)    REFERENCES Assets(asset_id)
);

----Quick check
-- Row counts
SELECT COUNT(*) FROM Members;
SELECT COUNT(*) FROM Portfolios;
SELECT COUNT(*) FROM Assets;
SELECT COUNT(*) FROM Trades;
-- Orphans (should be zero rows)
SELECT p.portfolio_id
FROM Portfolios p LEFT JOIN Members m ON m.member_id = p.member_id
WHERE m.member_id IS NULL;
-------------/
SELECT t.trade_id
FROM Trades t LEFT JOIN Portfolios p ON p.portfolio_id = t.portfolio_id
WHERE p.portfolio_id IS NULL;
SELECT t.trade_id
FROM Trades t LEFT JOIN Assets a ON a.asset_id = t.asset_id
WHERE a.asset_id IS NULL;
-- (Optional) Portfolios created before member joined
SELECT p.portfolio_id, p.member_id, p.created_date, m.join_date
FROM Portfolios p
JOIN Members m ON m.member_id = p.member_id
WHERE date(p.created_date) < date(m.join_date);


