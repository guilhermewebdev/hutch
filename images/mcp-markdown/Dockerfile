FROM node:20-slim

# @modelcontextprotocol/server-filesystem — MCP server that exposes a directory
# supergateway — wraps any stdio MCP server over HTTP/SSE for networked access
RUN npm install -g \
    @modelcontextprotocol/server-filesystem \
    supergateway

RUN mkdir -p /hutch-mcp

EXPOSE 3000

# supergateway bridges the stdio MCP server to HTTP/SSE on port 3000.
# The command to run the MCP server must be passed as a string to --stdio.
# Default output transport is SSE when --stdio is used.
CMD ["supergateway", "--port", "3000", "--stdio", "mcp-server-filesystem /hutch-mcp"]
