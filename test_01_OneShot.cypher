// ---------------------------------------------------------------------------
// 1. Constraints e índices (Neo4j 5+ compatible)
// ---------------------------------------------------------------------------

CREATE CONSTRAINT branch_id_unique IF NOT EXISTS FOR (b:Branch)        REQUIRE b.branch_id IS UNIQUE;
CREATE CONSTRAINT teller_id_unique IF NOT EXISTS FOR (t:Teller)        REQUIRE t.teller_id IS UNIQUE;
CREATE CONSTRAINT client_id_unique IF NOT EXISTS FOR (c:Client)        REQUIRE c.client_id IS UNIQUE;
CREATE CONSTRAINT account_id_unique IF NOT EXISTS FOR (a:Account)      REQUIRE a.account_id IS UNIQUE;
CREATE CONSTRAINT group_id_unique IF NOT EXISTS FOR (g:Grp5MinMonto)  REQUIRE g.group_id IS UNIQUE;
CREATE CONSTRAINT batch_id_unique IF NOT EXISTS FOR (r:RutaDinero)    REQUIRE r.batch_id IS UNIQUE;
CREATE CONSTRAINT txn_id_unique IF NOT EXISTS FOR (x:Transaction)     REQUIRE x.txn_id IS UNIQUE;

CREATE INDEX branch_state_index IF NOT EXISTS FOR (br:Branch) ON (br.state);
CREATE INDEX txn_ts_index IF NOT EXISTS FOR (tx:Transaction) ON (tx.txn_ts);
