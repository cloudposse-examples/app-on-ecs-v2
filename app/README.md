# Example Application

A simple Go web server designed to demonstrate container deployment strategies. Each request increments a counter, and the background color is configurable via environment variable - making it easy to visualize blue/green deployments, canary releases, and load balancing across multiple instances.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `/` | Index page with configurable background color and request counter that increments on each refresh |
| `/dashboard` | Grid of auto-refreshing iframes showing the index page - useful for visualizing load balancing across multiple container instances |
| `/healthz` | Health check endpoint (returns `OK`) |
| `/shutdown` | Graceful shutdown trigger |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `COLOR` | `green` | Background color for the index page |
| `LISTEN` | `:8080` | Address and port to listen on |

## Local Development

Run the application locally using Podman Compose:

```bash
# From repository root
atmos up    # Builds and runs on http://localhost:8080
atmos down  # Stop the app
```

## Building

```bash
# Build Docker image
docker build -t app-on-ecs-v2 app/

# Run locally
docker run -p 8080:8080 -e COLOR=blue app-on-ecs-v2
```

## Files

- `main.go` - Go web server
- `Dockerfile` - Multi-stage Docker build (Alpine)
- `public/` - Static HTML assets
- `rootfs/` - Container filesystem overlay (entrypoint script)
