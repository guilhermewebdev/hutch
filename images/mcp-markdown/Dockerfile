FROM node:20-slim

# @modelcontextprotocol/server-filesystem — MCP server that exposes a directory
# supergateway — wraps any stdio MCP server over HTTP/SSE for networked access
RUN npm install -g \
    @modelcontextprotocol/server-filesystem \
    supergateway

RUN mkdir -p /hutch-mcp

EXPOSE 3000

# supergateway bridges the stdio MCP server to HTTP/SSE on port 3000.
# Clients connect to http://<host>:3000/sse
# Added --sse to specify the protocol as required by supergateway
CMD ["supergateway", "--port", "3000", "--sse", "--", "mcp-server-filesystem", "/hutch-mcp"]
