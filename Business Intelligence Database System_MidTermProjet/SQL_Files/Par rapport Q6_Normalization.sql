UPDATE Trades SET trade_type = 'BUY'  WHERE trade_type LIKE 'BUY%';
UPDATE Trades SET trade_type = 'SELL' WHERE trade_type LIKE 'SELL%';


SELECT trade_type, COUNT(*) FROM Trades GROUP BY trade_type;

--- NOTE -------------------------
