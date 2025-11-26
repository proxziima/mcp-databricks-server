# Dockerfile for MCP Databricks Server with SuperGateway
# This exposes the Python MCP server via Streamable HTTP for remote HTTPS access

FROM node:20-slim AS gateway

# Install Python and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Install SuperGateway globally
RUN npm install -g supergateway

WORKDIR /app

# Copy Python requirements and install dependencies
COPY requirements.txt .
RUN python3 -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# Copy Python MCP server code
COPY *.py ./

# Environment variables for Databricks
ENV DATABRICKS_HOST=""
ENV DATABRICKS_TOKEN=""
ENV DATABRICKS_SQL_WAREHOUSE_ID=""

# SuperGateway configuration for Streamable HTTP
ENV PORT=8000
ENV STREAMABLE_HTTP_PATH="/mcp"

# Add virtual environment to PATH
ENV PATH="/opt/venv/bin:$PATH"

# Expose the HTTP port
EXPOSE 8000

# Start SuperGateway with Streamable HTTP transport (stateless mode)
CMD supergateway \
    --stdio "python main.py" \
    --outputTransport streamableHttp \
    --port ${PORT} \
    --streamableHttpPath ${STREAMABLE_HTTP_PATH} \
    --cors \
    --healthEndpoint /health \
    --healthEndpoint /healthz
