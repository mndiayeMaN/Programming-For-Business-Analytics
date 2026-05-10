PRAGMA foreign_keys = ON;

--------------------------------------------------------------------------------
-- R1. For each portfolio, count trades and sum traded value in the last 30 days
-- Use: Identify most/least active portfolios recently (coaching & demos) for mentoring and workload planning.
--------------------------------------------------------------------------------
WITH recent AS (
  SELECT *
  FROM Trades
  WHERE date(trade_date) >= date('now','-30 day')
)
SELECT
  p.portfolio_id,
  p.portfolio_name,
  m.first_name || ' ' || m.last_name AS owner,
  COUNT(r.trade_id)                                         AS trade_count,
  ROUND(SUM(r.quantity * r.trade_price), 2)                 AS total_traded_value,
  ROUND(SUM(CASE WHEN r.trade_type='BUY'  THEN r.quantity*r.trade_price ELSE 0 END), 2) AS buy_value,
  ROUND(SUM(CASE WHEN r.trade_type='SELL' THEN r.quantity*r.trade_price ELSE 0 END), 2) AS sell_value
FROM Portfolios p
JOIN Members m ON m.member_id = p.member_id
LEFT JOIN recent r ON r.portfolio_id = p.portfolio_id
GROUP BY p.portfolio_id, p.portfolio_name, owner
ORDER BY total_traded_value DESC NULLS LAST;

--------------------------------------------------------------------------------
-- R2. By asset type (stock/crypto/fund): trade counts and share of total value
-- Use: Show where trading effort and dollars concentrate (stocks vs crypto vs funds) to guide education and risk focus.
--------------------------------------------------------------------------------
WITH per_trade AS (
  SELECT a.asset_type, (t.quantity * t.trade_price) AS value
  FROM Trades t
  JOIN Assets a ON a.asset_id = t.asset_id
),
agg AS (
  SELECT asset_type,
         COUNT(*)               AS trade_count,
         ROUND(SUM(value), 2)   AS traded_value
  FROM per_trade
  GROUP BY asset_type
),
tot AS (SELECT SUM(traded_value) AS tv FROM agg)
SELECT
  a.asset_type,
  a.trade_count,
  a.traded_value,
  ROUND(100.0 * a.traded_value / t.tv, 2) AS pct_of_total
FROM agg a CROSS JOIN tot t
ORDER BY a.traded_value DESC;

--------------------------------------------------------------------------------
--- R3. For each member: total BUY value, total SELL value, and gross profit (simple)
--- Use: Give each member a simplified cash-flow view to discuss position sizing and selling discipline
--------------------------------------------------------------------------------
WITH per_trade AS (
  SELECT
    p.member_id,
    t.trade_type,
    (t.quantity * t.trade_price) AS value
  FROM Trades t
  JOIN Portfolios p ON p.portfolio_id = t.portfolio_id
)
SELECT
  m.member_id,
  m.first_name || ' ' || m.last_name AS member_name,
  ROUND(SUM(CASE WHEN trade_type='BUY'  THEN value ELSE 0 END), 2) AS total_buy_value,
  ROUND(SUM(CASE WHEN trade_type='SELL' THEN value ELSE 0 END), 2) AS total_sell_value,
  ROUND(
    SUM(CASE WHEN trade_type='SELL' THEN value ELSE 0 END) -
    SUM(CASE WHEN trade_type='BUY'  THEN value ELSE 0 END), 2
  ) AS gross_profit_est
FROM Members m
LEFT JOIN per_trade x ON x.member_id = m.member_id
GROUP BY m.member_id, member_name
ORDER BY gross_profit_est DESC;

--------------------------------------------------------------------------------
-- R4. Top 5 assets by approximate current holdings across all portfolios (buys−sells)
-- Use: Identify the club’s largest positions to monitor risk and plan updates to members.
--------------------------------------------------------------------------------
WITH pos AS (
  SELECT
    a.asset_id,
    a.symbol,
    SUM(CASE WHEN t.trade_type='BUY'  THEN t.quantity ELSE 0 END) -
    SUM(CASE WHEN t.trade_type='SELL' THEN t.quantity ELSE 0 END) AS qty_held
  FROM Trades t
  JOIN Assets a ON a.asset_id = t.asset_id
  GROUP BY a.asset_id, a.symbol
)
SELECT asset_id, symbol, ROUND(qty_held, 6) AS qty_held
FROM pos
ORDER BY qty_held DESC
LIMIT 5;

--------------------------------------------------------------------------------
-- R5. Monthly trading volume and net buy amount by year-month
-- Use: Track trading trends over time and detect months with net inflows/outflows for meeting summaries
--------------------------------------------------------------------------------
WITH t AS (
  SELECT
    strftime('%Y-%m', trade_date) AS ym,
    trade_type,
    (quantity * trade_price)      AS trade_value
  FROM Trades
)
SELECT
  ym,
  COUNT(*) AS trade_count,
  ROUND(SUM(CASE WHEN trade_type='BUY'  THEN trade_value ELSE 0 END), 2) AS buy_value,
  ROUND(SUM(CASE WHEN trade_type='SELL' THEN trade_value ELSE 0 END), 2) AS sell_value,
  ROUND(
    SUM(CASE WHEN trade_type='BUY'  THEN trade_value ELSE 0 END) -
    SUM(CASE WHEN trade_type='SELL' THEN trade_value ELSE 0 END), 2
  ) AS net_buy_value
FROM t
GROUP BY ym
ORDER BY ym;

--------------------------------------------------------------------------------
-- R6. Compare average portfolio cost basis on a symbol to current price (unrealized)
-- Use: Estimate unrealized gains/losses per portfolio & symbol to prioritize reviews (approximate, no FIFO/LIFO)

--------------------------------------------------------------------------------

-- One-time cleanup: normalize trade_type
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
--- UPDATE Trades SET trade_type = 'BUY'  WHERE trade_type LIKE 'BUY%';
--- UPDATE Trades SET trade_type = 'SELL' WHERE trade_type LIKE 'SELL%';

-- Quick check (facultatif)
--- SELECT trade_type, COUNT(*) FROM Trades GROUP BY trade_type;
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

WITH flows AS (
  SELECT
    t.portfolio_id,
    a.asset_id,
    a.symbol,
    a.current_price,
    SUM(CASE WHEN t.trade_type='BUY'  THEN t.quantity ELSE 0 END)                 AS buy_qty,
    SUM(CASE WHEN t.trade_type='BUY'  THEN t.quantity * t.trade_price ELSE 0 END) AS buy_cost,
    SUM(CASE WHEN t.trade_type='SELL' THEN t.quantity ELSE 0 END)                 AS sell_qty
  FROM Trades t
  JOIN Assets a ON a.asset_id = t.asset_id
  GROUP BY t.portfolio_id, a.asset_id, a.symbol, a.current_price
),
pos AS (
  SELECT
    portfolio_id,
    asset_id,
    symbol,
    current_price,
    (buy_qty - sell_qty)                                           AS qty_held,
    CASE WHEN buy_qty > 0 THEN buy_cost / buy_qty ELSE NULL END    AS avg_cost
  FROM flows
)
SELECT
  pos.portfolio_id,
  f.portfolio_name,
  pos.asset_id,
  pos.symbol,
  ROUND(pos.qty_held, 6) AS qty_held,
  ROUND(pos.avg_cost, 2) AS avg_cost,
  pos.current_price,
  ROUND(pos.qty_held * (pos.current_price - pos.avg_cost), 2) AS approx_unrealized_pl
FROM pos
JOIN Portfolios f ON f.portfolio_id = pos.portfolio_id
WHERE pos.qty_held > 0
  AND pos.avg_cost IS NOT NULL
ORDER BY approx_unrealized_pl DESC, pos.portfolio_id, pos.symbol;


----  My 2 original queries
--------------------------------------------------------------------------------

--- O1 – Inactive portfolios (no trades in 90 days)
-- Use: Re-engagement list for mentors; flag portfolios that may need guidance or check-ins.
--------------------------------------------------------------------------------
WITH last_trade AS (
  SELECT p.portfolio_id, MAX(t.trade_date) AS last_trade_date
  FROM Portfolios p
  LEFT JOIN Trades t ON t.portfolio_id = p.portfolio_id
  GROUP BY p.portfolio_id
)
SELECT
  p.portfolio_id,
  p.portfolio_name,
  m.first_name || ' ' || m.last_name AS owner,
  last_trade.last_trade_date
FROM Portfolios p
JOIN Members m ON m.member_id = p.member_id
LEFT JOIN last_trade ON last_trade.portfolio_id = p.portfolio_id
WHERE last_trade.last_trade_date IS NULL
   OR date(last_trade.last_trade_date) < date('now','-90 day')
ORDER BY last_trade.last_trade_date NULLS FIRST, p.portfolio_id;

--------------------------------------------------------------------------------

----- O2 - Peak trading day per portfolio: For each portfolio, return the single day with the highest total traded value (peak trading day)
--- Use: Find each portfolio’s busiest day to review decisions, fees, and lessons learned.

--------------------------------------------------------------------------------
WITH per_day AS (
  SELECT
    t.portfolio_id,
    t.trade_date,
    ROUND(SUM(t.quantity * t.trade_price), 2) AS day_value
  FROM Trades t
  GROUP BY t.portfolio_id, t.trade_date
),
ranked AS (
  SELECT
    per_day.*,
    ROW_NUMBER() OVER (PARTITION BY portfolio_id ORDER BY day_value DESC) AS rn
  FROM per_day
)
SELECT
  r.portfolio_id,
  p.portfolio_name,
  r.trade_date,
  r.day_value
FROM ranked r
JOIN Portfolios p ON p.portfolio_id = r.portfolio_id
WHERE r.rn = 1
ORDER BY r.day_value DESC;









