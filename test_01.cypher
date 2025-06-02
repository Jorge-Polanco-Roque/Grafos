// Esto pegar en Neo4j Browser

:auto
CALL () {
  LOAD CSV WITH HEADERS FROM 'file:///captacion_operacion.csv' AS row

  // 1. Filtra filas con txn_id inválido
  WITH row
  WHERE row.txn_id IS NOT NULL

  // 2. Conversión de tipos y limpieza de valores vacíos
  WITH
    toInteger(row.txn_id) AS txn_id,
    row.branch_id AS branch_id,
    row.teller_id AS teller_id,
    row.account_id AS account_id,
    row.client_id AS client_id,
    datetime(row.txn_ts) AS txn_ts,
    datetime(row.processing_ts) AS processing_ts,
    toFloat(row.amount_mxn) AS amount_mxn,
    row.currency AS currency,
    row.channel AS channel,
    row.device_id AS device_id,
    CASE row.ip_address WHEN '' THEN null ELSE row.ip_address END AS ip_address,
    CASE row.group_id_5min_monto WHEN '' THEN null ELSE row.group_id_5min_monto END AS group_id,
    CASE row.batch_id_ruta_dinero WHEN '' THEN null ELSE row.batch_id_ruta_dinero END AS batch_id,
    CASE row.alert_flags WHEN '' THEN null ELSE row.alert_flags END AS alert_flags,
    toFloat(row.risk_score) AS risk_score,
    CASE row.reversed WHEN 'True' THEN true ELSE false END AS reversed,
    CASE row.audit_user WHEN '' THEN null ELSE row.audit_user END AS audit_user,
    datetime(row.inserted_at) AS inserted_at

  // 3. MERGE de entidades base
  MERGE (br:Branch {branch_id: branch_id})
    ON CREATE SET br.name = CASE branch_id
      WHEN 'S001' THEN 'Monterrey Centro'
      WHEN 'S002' THEN 'Guadalajara Roma'
      WHEN 'S003' THEN 'Tijuana Plaza Río'
      WHEN 'S004' THEN 'Tuxtla Centro'
      WHEN 'S005' THEN 'Culiacán Forjadores'
      ELSE 'Sucursal desconocida'
    END

  MERGE (tl:Teller {teller_id: teller_id})
  MERGE (cl:Client {client_id: client_id})
  MERGE (ac:Account {account_id: account_id})
    ON CREATE SET ac.opened_at = date(txn_ts)  // <--- Cambio aquí

  // 4. Crear entidades condicionales si hay ID
  FOREACH (_ IN CASE WHEN group_id IS NOT NULL THEN [1] ELSE [] END |
    MERGE (:Grp5MinMonto {group_id: group_id})
  )

  FOREACH (_ IN CASE WHEN batch_id IS NOT NULL THEN [1] ELSE [] END |
    MERGE (:RutaDinero {batch_id: batch_id})
  )

  // 5. Crear nodo transacción
  CREATE (tx:Transaction {
    txn_id: txn_id,
    txn_ts: txn_ts,
    processing_ts: processing_ts,
    amount_mxn: amount_mxn,
    currency: currency,
    channel: channel,
    device_id: device_id,
    ip_address: ip_address,
    alert_flags: alert_flags,
    risk_score: risk_score,
    reversed: reversed,
    audit_user: audit_user,
    inserted_at: inserted_at
  })

  // 6. Relaciones principales
  MERGE (tx)-[:PERFORMED_AT]->(br)
  MERGE (tx)-[:EXECUTED_BY]->(tl)
  MERGE (ac)-[:BELONGS_TO]->(cl)
  MERGE (tx)-[:ON_ACCOUNT]->(ac)

  // 7. MATCH nodos condicionales externos
  WITH tx, ac, cl, tl, br, group_id, batch_id
  OPTIONAL MATCH (grp:Grp5MinMonto {group_id: group_id})
  OPTIONAL MATCH (rt:RutaDinero {batch_id: batch_id})
  WITH tx, grp, rt

  // 8. Relaciones condicionales
  FOREACH (_ IN CASE WHEN grp IS NOT NULL THEN [1] ELSE [] END |
    MERGE (tx)-[:PART_OF_GROUP]->(grp)
  )
  FOREACH (_ IN CASE WHEN rt IS NOT NULL THEN [1] ELSE [] END |
    MERGE (tx)-[:IN_BATCH_RUTA_DINERO]->(rt)
  )
} IN TRANSACTIONS OF 500 ROWS;
