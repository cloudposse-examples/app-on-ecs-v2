FROM golang:1.26-alpine AS builder

# Copy source into builder
COPY . /src

# Build the app
RUN cd /src && \
    go build -ldflags="-s -w" -trimpath -o example-app

# Build the final image
FROM alpine:3.22 AS final

RUN apk add --no-cache bash curl && \
    addgroup -S app && adduser -S app -G app

# Expose port of the app
EXPOSE 8080

# Set the runtime working directory
WORKDIR /app

# Copy public assets
COPY public/ /app/public/

COPY rootfs/ /



# Install the app
COPY --from=builder /src/example-app /app/

RUN chown -R app:app /app

USER app

# Define the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["./example-app"]
