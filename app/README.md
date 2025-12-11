# Example Application

A simple Go web server that serves static HTML pages.

## Endpoints

| Endpoint | Description |
|----------|-------------|
| `/` | Index page with configurable color and request counter |
| `/dashboard` | Dashboard view |
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
