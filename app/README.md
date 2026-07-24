# Example Application

A simple Go web server designed to demonstrate container deployment strategies and ECS runtime secret injection. Each request increments a counter, the background color is configurable via environment variable, and the app reports whether the demonstration `API_KEY` secret was configured without displaying the value.

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
| `API_KEY` | unset | Demonstration secret. The app only reports whether it is configured; it never displays the value. |

## Local Development

Run the application locally using Atmos 1.224 native containers:

```bash
# From repository root
atmos up    # Builds and runs on http://localhost:8080
atmos logs  # Stream container logs
atmos down  # Stop the app
```

The local container component is defined in `terraform/stacks/local.yaml`.

## Building

```bash
# Build Docker image
docker build -t atmos-native-ci app/

# Run locally
docker run -p 8080:8080 -e COLOR=blue atmos-native-ci
```

## Files

- `main.go` - Go web server
- `Dockerfile` - Multi-stage Docker build (Alpine)
- `public/` - Static HTML assets
- `rootfs/` - Container filesystem overlay (entrypoint script)
