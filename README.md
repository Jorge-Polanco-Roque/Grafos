# Neo4j Graph Analytics Starter 🚀

> Quick start guide to exploring transactional banking data with Neo4j, Cypher, and the Graph Data Science (GDS) library.

---

## 🤔 What is Neo4j?

**Neo4j** is a native **property‑graph** database where nodes and relationships carry structured data **and** are stored as a graph. It excels at questions that are hard or unnatural in relational stores—think *paths*, *recommendations*, *fraud rings*, and *network influence*.

**Key characteristics**

* ACID transactions & flexible schema
* Cypher query language (SQL‑like but graph‑native)
* Native storage & processing for millisecond‑level traversals

---

## 🧩 Core Components

| Component                    | TL;DR                                                                            | Typical Use                                                      |
| ---------------------------- | -------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| **Neo4j Browser**            | Code‑centric IDE shipped with every Neo4j instance.                              | Run ad‑hoc Cypher, visualize graphs, inspect query plans.        |
| **Neo4j Bloom**              | Low‑code graph exploration with natural‑language search.                         | Business‑friendly storytelling & interactive graph walkthroughs. |
| **Graph Data Science (GDS)** | In‑database algorithms & pipelines (centrality, community, link prediction, ML). | Large‑scale analytics & production pipelines without ETL.        |

> 🔍 **Tip:** Browser for devs, Bloom for analysts, GDS for data‑scientists.

---

## 💡 What the Cypher Scripts Demonstrate

1. **Exploratory Queries**

   * Retrieve the 10 most recent transactions.
   * Join each transaction to its branch, teller, account, and client.
   * Drill into a single transaction with *optional* matches for enriched context.

2. **GDS Projection & Centrality**

   * `gds.graph.project` builds **transacciones\_entre\_clientes** (Clients ↔ Transactions ↔ Accounts).
   * Runs **PageRank**, **Degree**, **Betweenness**, and **Louvain** to surface influential clients & communities.
   * Uses `gds.wcc.stream` to detect the biggest connected components (potential fraud rings).

3. **Similarity‑Based Client Network**

   * Creates a bipartite *Client → Branch* graph weighted by transaction count (`:VISITO{nTx}`).
   * `gds.nodeSimilarity.write` converts branch‑overlap into **CONECTADO** edges between clients.
   * Projects **clientes\_conectados** and re‑runs PageRank / Louvain for behavioural clusters.

4. **Persisting Insights**

   * Writes `pagerank` & `community` back to each `Client` node, ready for Bloom or downstream ML pipelines.

---

## 🛠 Quick Start

```bash
# Spin up Neo4j (Docker example)
docker run \
  --name neo4j-graph \
  -p7474:7474 -p7687:7687 \
  -e NEO4J_ACCEPT_LICENSE_AGREEMENT=yes \
  -e NEO4J_AUTH=neo4j/test \
  neo4j:5

# Open http://localhost:7474 and paste the Cypher from docs/scripts.cypher
```

> **Prerequisites:** Neo4j 5.x with the **Graph Data Science** plugin installed.

---

## 📚 Further Reading

* [Neo4j Documentation](https://neo4j.com/docs/)
* [Cypher Manual](https://neo4j.com/docs/cypher-manual/current/)
* [Graph Data Science Guide](https://neo4j.com/docs/graph-data-science/current/)
* [Neo4j Bloom Overview](https://neo4j.com/developer/bloom/)

---
