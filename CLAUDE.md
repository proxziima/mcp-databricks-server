# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Model Context Protocol (MCP) server that enables LLMs to interact with Databricks Unity Catalog and execute SQL queries. The server exposes tools for browsing Unity Catalog metadata (catalogs, schemas, tables), analyzing data lineage (including notebook and job dependencies), and executing SQL queries.

## Architecture

**Core Components:**

- `main.py`: FastMCP server entry point that defines the MCP tools and handles async execution
- `databricks_sdk_utils.py`: Databricks SDK integration layer that handles all UC metadata retrieval, lineage fetching, and SQL execution
- `databricks_formatter.py`: Formats query results and metadata into markdown for LLM consumption

**Key Design Patterns:**

- The server uses `asyncio.to_thread()` to run synchronous Databricks SDK calls in thread pool
- Global `WorkspaceClient` is initialized once at module import in `databricks_sdk_utils.py`
- Job and notebook information is cached to avoid redundant API calls during lineage fetching
- All outputs are formatted as Markdown for optimal LLM parsing

## Development Commands

**Setup environment:**
```bash
# Install dependencies with pip
pip install -r requirements.txt

# Or with uv (recommended)
uv pip install -r requirements.txt
```

**Running the server:**
```bash
# Run standalone (stdio transport for MCP clients)
python main.py

# Or with uv
uv run main.py
```

**Configuration:**

Required environment variables (set via `.env` file or shell):
- `DATABRICKS_HOST`: Databricks workspace URL
- `DATABRICKS_TOKEN`: Personal access token or service principal token
- `DATABRICKS_SQL_WAREHOUSE_ID`: SQL warehouse ID (for SQL execution and lineage)

## MCP Tools Implementation

The server exposes 5 MCP tools:

1. `list_uc_catalogs()` - Lists all available catalogs
2. `describe_uc_catalog(catalog_name)` - Shows schemas within a catalog
3. `describe_uc_schema(catalog_name, schema_name, include_columns)` - Shows tables in a schema, optionally with column details
4. `describe_uc_table(full_table_name, include_lineage)` - Shows table structure with optional comprehensive lineage (upstream/downstream tables, notebooks, jobs)
5. `execute_sql_query(sql)` - Executes SQL queries and returns formatted results

## Databricks SDK Integration

**SDK Configuration:**

- Client uses 30s HTTP timeout and 60s retry timeout
- Connection is initialized at module import with config from environment variables
- If `DATABRICKS_HOST` or `DATABRICKS_TOKEN` are missing, module raises `ImportError`

**Lineage Fetching:**

When `include_lineage=True` for table descriptions:
- Fetches upstream/downstream table dependencies via Unity Catalog lineage API
- Identifies notebooks that read/write the table
- Enriches notebook info with associated Databricks job details
- Caches job information to minimize API calls

## Docker Deployment

The `Dockerfile` uses SuperGateway to expose the stdio MCP server via HTTP/SSE:

- Based on `node:20-slim` with Python 3 installed
- SuperGateway proxies stdio MCP protocol to HTTP endpoints
- Exposes port 8000 with `/sse` and `/message` endpoints
- Health checks available at `/health` and `/healthz`
- CORS enabled for browser access

**Build and run:**
```bash
docker build -t mcp-databricks-server .
docker run -p 8000:8000 \
  -e DATABRICKS_HOST="your-host" \
  -e DATABRICKS_TOKEN="your-token" \
  -e DATABRICKS_SQL_WAREHOUSE_ID="your-warehouse-id" \
  mcp-databricks-server
```

## Key Considerations

**Error Handling:**

- All MCP tools catch exceptions and return user-friendly error messages
- SQL execution distinguishes between query failures, execution errors, and success
- Missing SDK initialization raises ImportError with instructions

**Performance:**

- Lineage fetching can be slow for tables with many dependencies
- Job/notebook caching significantly reduces API calls during lineage operations
- Query timeout is set to 50s in `execute_databricks_sql` function

**Security:**

- Never commit `.env` file (contains sensitive tokens)
- Use service principals with minimal required permissions for production
- The `.env` file should contain only the three required environment variables
