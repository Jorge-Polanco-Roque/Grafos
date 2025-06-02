// =============================================================
// 0. LIMPIEZA PREVIA
//    ──────────────────
//    Para evitar conflictos con proyecciones antiguas, primero
//    eliminamos (sin error si no existen) los grafos GDS usados
//    a lo largo del script.
// =============================================================
CALL gds.graph.drop('transacciones_entre_clientes', false);   // Grafo transaccional
CALL gds.graph.drop('cliente_sucursal',              false);   // Grafo bipartito cliente-sucursal
CALL gds.graph.drop('clientes_conectados',           false);   // Grafo final sólo-clientes



// =============================================================
// 1. CONSULTAS EXPLORATORIAS BÁSICAS
//    ───────────────────────────────
//    Ayudan a inspeccionar rápidamente las transacciones antes
//    de construir los grafos.
// =============================================================

// 1-A. Diez transacciones más recientes
MATCH (t:Transaction)                // Selecciona todas las transacciones
RETURN t                             // Devuelve cada nodo Transaction
ORDER BY t.txn_ts DESC               // Ordena por timestamp descendente
LIMIT 10;                            // Máximo 10 filas


// 1-B. Muestra de 20 transacciones con contexto completo
MATCH (t:Transaction)-[:PERFORMED_AT]->(b:Branch),            // Sucursal donde ocurrió
      (t)-[:EXECUTED_BY]->(tl:Teller),                        // Cajero que la ejecutó
      (t)-[:ON_ACCOUNT]->(ac:Account)-[:BELONGS_TO]->(cl:Client) // Cuenta ↔ Cliente
RETURN t, b, tl, ac, cl                                       // Devuelve todo el contexto
LIMIT 20;                                                     // Máximo 20 filas


// 1-C. Detalle completo de una transacción específica
MATCH (t:Transaction {txn_id: 990000000007})                  // ID exacto
OPTIONAL MATCH (t)-[:PERFORMED_AT]->(b:Branch)                // Sucursal (si existe)
OPTIONAL MATCH (t)-[:EXECUTED_BY]->(tl:Teller)                // Cajero  (si existe)
OPTIONAL MATCH (t)-[:ON_ACCOUNT]->(ac:Account)-[:BELONGS_TO]->(cl:Client)
OPTIONAL MATCH (t)-[:PART_OF_GROUP]->(g:Grp5MinMonto)         // Agrupación por monto
OPTIONAL MATCH (t)-[:IN_BATCH_RUTA_DINERO]->(rd:RutaDinero)   // Batch de ruta de dinero
RETURN t, b, tl, ac, cl, g, rd;                               // Resultado consolidado



// =============================================================
// 2. PROYECCIÓN ①: “transacciones_entre_clientes”
//    ─────────────────────────────────────────────
//    Incluye nodos Client, Transaction y Account, conectados
//    vía relaciones invertidas BELONGS_TO y ON_ACCOUNT.
//    Útil para métricas de centralidad sobre la red transaccional.
// =============================================================
CALL gds.graph.project(
  'transacciones_entre_clientes',           // Nombre del grafo
  ['Client', 'Transaction', 'Account'],     // Conjunto de nodos
  {                                         // Relaciones (todas en dirección inversa)
    BELONGS_TO: { type: 'BELONGS_TO', orientation: 'REVERSE' },
    ON_ACCOUNT: { type: 'ON_ACCOUNT', orientation: 'REVERSE' }
  }
);



// -------------------------------------------------------------
// 2-A. PageRank   → clientes con mayor “influencia” transaccional
// -------------------------------------------------------------
CALL gds.pageRank.stream('transacciones_entre_clientes')
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS n, score     // Convierte nodeId a nodo real
WHERE n:Client                               // Sólo nodos Client
RETURN n.client_id         AS cliente,
       round(score,4)      AS pagerank
ORDER BY pagerank DESC
LIMIT 10;



// -------------------------------------------------------------
// 2-B. Louvain   → comunidades de clientes por transacciones
// -------------------------------------------------------------
CALL gds.louvain.stream('transacciones_entre_clientes')
YIELD nodeId, communityId
WITH gds.util.asNode(nodeId) AS n, communityId
WHERE n:Client
RETURN communityId,
       collect(n.client_id)[0..5] AS ejemplo_clientes,   // Muestra de 5 clientes
       count(*)                 AS miembros
ORDER BY miembros DESC
LIMIT 8;



// -------------------------------------------------------------
// 2-C. Degree centrality   → clientes con más conexiones directas
// -------------------------------------------------------------
CALL gds.degree.stream('transacciones_entre_clientes')
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS n, score
WHERE n:Client
RETURN n.client_id AS cliente,
       score       AS grado
ORDER BY grado DESC
LIMIT 10;



// -------------------------------------------------------------
// 2-D. Betweenness centrality   → clientes que actúan de puentes
// -------------------------------------------------------------
CALL gds.betweenness.stream('transacciones_entre_clientes')
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS n, score
WHERE n:Client
RETURN n.client_id AS cliente,
       round(score,2) AS intermediacion
ORDER BY intermediacion DESC
LIMIT 10;



// -------------------------------------------------------------
// 2-E. Componentes fuertemente conectados
// -------------------------------------------------------------
CALL gds.wcc.stream('transacciones_entre_clientes')
YIELD nodeId, componentId
WITH gds.util.asNode(nodeId) AS n, componentId
WHERE n:Client
RETURN componentId,
       collect(n.client_id)[0..5] AS clientes_ejemplo,
       count(*)                   AS total_en_componente
ORDER BY total_en_componente DESC
LIMIT 5;



// =============================================================
// 3. CREAR GRAFO BIPARTITO Cliente–Sucursal
//    ───────────────────────────────────────
//    3-A. Genera (o actualiza) la relación (c)-[:VISITO]->(b)
//         con peso nTx = número de transacciones.
// =============================================================
MATCH (c:Client)<-[:BELONGS_TO]-(:Account)<-[:ON_ACCOUNT]-
      (t:Transaction)-[:PERFORMED_AT]->(b:Branch)
WITH c, b, count(*) AS nTx                      // # transacciones c→b
MERGE (c)-[r:VISITO]->(b)                       // Crea/actualiza relación
  ON CREATE SET r.nTx = nTx                     // Nuevo: asigna nTx
  ON MATCH  SET r.nTx = r.nTx + nTx;            // Existente: acumula nTx



// 3-B. Proyecta el grafo bipartito “cliente_sucursal”
CALL gds.graph.project(
  'cliente_sucursal',
  ['Client','Branch'],                          // Dos tipos de nodos
  {
    VISITO: {
      type:        'VISITO',
      orientation: 'NATURAL',                  // Client → Branch
      properties:  'nTx'                       // Peso de la arista
    }
  }
);



// =============================================================
// 4. SIMILARIDAD DE CLIENTES Y GRAFO FINAL “clientes_conectados”
//    ───────────────────────────────────────────────────────────
//    4-A. Calcula nodeSimilarity y escribe (c)-[:CONECTADO {sim}]→(c2)
// =============================================================
CALL gds.nodeSimilarity.write(
  'cliente_sucursal',
  {
    nodeLabels: ['Client'],          // Sólo compara clientes
    similarityCutoff: 0.20,          // Filtra similitud < 0.20
    topK: 10,                        // Máx. 10 vecinos por cliente
    writeRelationshipType: 'CONECTADO',
    writeProperty: 'sim'             // Guarda score en r.sim
  }
) YIELD relationshipsWritten;        // Resumen de escritura



// 4-B. Proyección exclusiva de clientes
CALL gds.graph.project(
  'clientes_conectados',
  'Client',                          // Un solo tipo de nodo
  {
    CONECTADO: {
      type:        'CONECTADO',
      orientation: 'UNDIRECTED',     // Grafo no dirigido
      properties:  'sim'             // Peso disponible
    }
  }
);



// -------------------------------------------------------------
// 4-C. PageRank sobre “clientes_conectados”
// -------------------------------------------------------------
CALL gds.pageRank.stream('clientes_conectados')
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).client_id AS cliente,
       round(score,4)                    AS pagerank
ORDER BY pagerank DESC
LIMIT 10;



// -------------------------------------------------------------
// 4-D. Louvain: escritura de comunidades en propiedad “community”
// -------------------------------------------------------------
CALL gds.louvain.write(
  'clientes_conectados',
  { writeProperty: 'community' }
) YIELD communityCount;                // Nº total de comunidades



// 4-E. Resumen de tamaños de comunidad
MATCH (c:Client)
RETURN c.community AS comunidad,
       count(*)    AS miembros
ORDER BY miembros DESC
LIMIT 10;
