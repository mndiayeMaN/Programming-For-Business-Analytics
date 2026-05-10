PRAGMA foreign_keys = ON;

/* 1) Row counts (should match your CSVs) */
SELECT (SELECT COUNT(*) FROM Members)    AS n_members,
       (SELECT COUNT(*) FROM Portfolios) AS n_portfolios,
       (SELECT COUNT(*) FROM Assets)     AS n_assets,
       (SELECT COUNT(*) FROM Trades)     AS n_trades;
 
/* 2) Orphan checks (each should return 0 rows) */
-- Portfolios without a valid Member
SELECT p.portfolio_id
FROM Portfolios p
LEFT JOIN Members m ON m.member_id = p.member_id
WHERE m.member_id IS NULL;

-- Trades without a valid Portfolio
SELECT t.trade_id
FROM Trades t
LEFT JOIN Portfolios p ON p.portfolio_id = t.portfolio_id
WHERE p.portfolio_id IS NULL;

-- Trades without a valid Asset
SELECT t.trade_id
FROM Trades t
LEFT JOIN Assets a ON a.asset_id = t.asset_id
WHERE a.asset_id IS NULL;
