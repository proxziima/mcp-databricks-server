# Multi-stage Dockerfile for Python MCP Databricks Server
# Stage 1: Dependencies
FROM python:3.10-slim AS deps

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency files
COPY requirements.txt ./

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Stage 2: Build
FROM python:3.10-slim AS builder

WORKDIR /app

# Copy dependencies from deps stage
COPY --from=deps /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=deps /usr/local/bin /usr/local/bin

# Copy source code
COPY . .

# Build arguments for environment variables (optional, can be overridden at runtime)
ARG DATABRICKS_HOST
ARG DATABRICKS_TOKEN
ARG DATABRICKS_SQL_WAREHOUSE_ID

# Set environment variables for build (if provided)
ENV DATABRICKS_HOST=${DATABRICKS_HOST:-your-databricks-instance.cloud.databricks.com}
ENV DATABRICKS_TOKEN=${DATABRICKS_TOKEN:-your-databricks-access-token}
ENV DATABRICKS_SQL_WAREHOUSE_ID=${DATABRICKS_SQL_WAREHOUSE_ID:-your-sql-warehouse-id}

# Stage 3: Production runtime
FROM python:3.10-slim AS runner

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd --system --gid 1001 appuser && \
    useradd --system --uid 1001 --gid appuser --create-home appuser

# Copy Python dependencies from builder
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application code
COPY --from=builder /app/*.py ./
COPY --from=builder /app/requirements.txt ./

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

USER appuser

# Environment variables (should be overridden at runtime)
ENV DATABRICKS_HOST="your-databricks-instance.cloud.databricks.com"
ENV DATABRICKS_TOKEN="your-databricks-access-token"
ENV DATABRICKS_SQL_WAREHOUSE_ID="your-sql-warehouse-id"
ENV PYTHONUNBUFFERED=1

# Health check (optional - checks if Python is responsive)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import sys; sys.exit(0)" || exit 1

# Start MCP server
CMD ["python", "main.py"]
