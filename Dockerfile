FROM docker.io/library/golang:1.27.1-alpine3.24@sha256:cd9a32216aee5667f957a62d13a10032a63fd58e14b3f3d9cc8c2122f501e95e AS build

WORKDIR /src
COPY . .

# Build the process-exporter command inside the container.
RUN CGO_ENABLED=0 make build

FROM scratch

COPY --from=build /src/process-exporter /bin/process-exporter

LABEL org.opencontainers.image.source=https://github.com/jcopi/process-exporter

# Run the process-exporter command by default when the container starts.
ENTRYPOINT ["/bin/process-exporter"]

# Document that the service listens on port 9256.
EXPOSE 9256
