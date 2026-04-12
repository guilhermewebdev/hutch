FROM node:20-slim

# @modelcontextprotocol/server-filesystem — MCP server that exposes a directory
# mcp-proxy — A TypeScript SSE proxy for MCP servers that use stdio transport.
RUN npm install -g \
    @modelcontextprotocol/server-filesystem \
    mcp-proxy

RUN mkdir -p /hutch-mcp

EXPOSE 3000

# mcp-proxy bridges the stdio MCP server to HTTP/SSE on port 3000.
# Clients connect to http://<host>:3000/sse
CMD ["mcp-proxy", "--port", "3000", "mcp-server-filesystem", "/hutch-mcp"]
