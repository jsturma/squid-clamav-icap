# squidclamav-docker

A Docker/Podman container for SquidClamAV - an ICAP service that integrates ClamAV antivirus scanning with Squid proxy.

## Description

This container provides a complete SquidClamAV setup with:
- **Squid HTTP Proxy** - Web proxy server
- **c-icap** - ICAP server framework
- **SquidClamAV** - ICAP service for ClamAV virus scanning
- **ClamAV** - Antivirus engine

The container is configured to scan web traffic through Squid proxy using ClamAV via the ICAP protocol.

## Building the Container

### Using Podman

```bash
podman build -t squidclamav:latest .
```

### Using Docker

```bash
docker build -t squidclamav:latest .
```

## Running the Container

### Basic Usage

**⚠️ IMPORTANT:** Always use the `--name` parameter when running the container. Without it, Podman/Docker will generate random names, making it difficult to manage the container.

The container runs in the background (`-d` flag) and keeps running with `tail -f /dev/null`. To view logs, use `podman logs` or `docker logs`.

```bash
# Run with explicit name (REQUIRED)
podman run -d --name squidclamav squidclamav:latest
```

Or with Docker:

```bash
# Run with explicit name (REQUIRED)
docker run -d --name squidclamav squidclamav:latest
```

**Note:** The container will appear to "hang" if run without `-d` because it uses `tail -f /dev/null` to keep running. Always use the `-d` (detached) flag to run in the background.

### Exposing Ports

The container exposes the following ports:
- **3128** - Squid HTTP proxy port
- **1344** - c-icap ICAP service port

To expose these ports to your host:

```bash
podman run -d --name squidclamav -p 3128:3128 -p 1344:1344 squidclamav:latest
```

## Configuration

### Squid Configuration

Squid is configured with ICAP support:
- ICAP services are enabled
- Request and response modification via ICAP
- ICAP service endpoint: `icap://127.0.0.1:1344/squidclamav`

### c-icap Configuration

The c-icap server is configured to:
- Allow access from all sources
- Run the SquidClamAV service module
- Listen on port 1344

### SquidClamAV Configuration

The following configuration options are commented out to avoid warnings:
- `enable_libarchive` - Disabled (libarchive not available)
- `banmaxsize` - Disabled

## Services

The container runs the following services:
- **Squid** - HTTP proxy server
- **c-icap** - ICAP server with SquidClamAV module
- **ClamAV** - Antivirus daemon (if database is available)

## ClamAV Database

The container automatically downloads ClamAV virus definitions using `freshclam` during startup. With ClamAV 1.0.9, the database downloads work correctly and are compatible with the latest database formats.

The databases are automatically updated during container startup. To manually update the database:

```bash
podman exec squidclamav freshclam
```

## Using ICAP from Command Line

The container includes `c-icap-client` for testing ICAP services directly. Here are some practical examples:

### Test ICAP Service (OPTIONS Request)

Check if the ICAP service is responding:

```bash
podman exec squidclamav c-icap-client -i 127.0.0.1 -p 1344 -s squidclamav
```

### Test Virus Scanning with a File

Scan a file through ICAP (response modification):

```bash
# Create output directory first (IMPORTANT: directory must exist)
podman exec squidclamav mkdir -p /tmp/test

# Create a test file
podman exec squidclamav bash -c "echo 'test content' > /tmp/test.txt"

# Scan it through ICAP (response modification)
# Use -resp for response modification, -f for the file to scan, -o for output
podman exec squidclamav c-icap-client -i 127.0.0.1 -p 1344 -s squidclamav \
  -resp http://example.com/test -f /tmp/test.txt -o /tmp/test/result.txt

# Check the result (may be empty if file passes scan)
podman exec squidclamav ls -lh /tmp/test/result.txt
podman exec squidclamav cat /tmp/test/result.txt
```

**Important Notes:**
- Always use **absolute paths** (starting with `/`) - relative paths like `./tmp/` won't work
- The output directory **must exist** before running the command
- If the file passes the scan, the output file may be empty or contain the original content
- Use `-d 1` for debug output to see what's happening

### Test with EICAR Test File

Test virus detection with the EICAR test file:

```bash
# Create output directory
podman exec squidclamav mkdir -p /tmp/test

# Download EICAR test file (standard test virus)
podman exec squidclamav wget -q -O /tmp/eicar_com.zip \
  https://secure.eicar.org/eicar_com.zip

# Scan it through ICAP (should be detected as virus)
podman exec squidclamav c-icap-client -i 127.0.0.1 -p 1344 -s squidclamav \
  -resp http://example.com/test -f /tmp/eicar_com.zip -o /tmp/test/scan_result.txt -d 1

# Check the result
podman exec squidclamav cat /tmp/test/scan_result.txt
```

### Test Through Squid Proxy

Test ICAP integration by making requests through Squid:

```bash
# Set proxy and make a request (curl is included in the container)
podman exec squidclamav curl -x http://127.0.0.1:3128 http://www.example.com

# Or from your host machine (if ports are exposed)
curl -x http://localhost:3128 http://www.example.com

# Test with verbose output to see ICAP interaction
podman exec squidclamav curl -v -x http://127.0.0.1:3128 http://www.example.com
```

### Request Modification Test

Test request modification (reqmod):

```bash
podman exec squidclamav c-icap-client -i 127.0.0.1 -p 1344 -s squidclamav \
  -req http://example.com/test -f /tmp/test.txt
```

### Response Modification Test

Test response modification (respmod):

```bash
podman exec squidclamav c-icap-client -i 127.0.0.1 -p 1344 -s squidclamav \
  -resp http://example.com/test -f /tmp/test.txt
```

### Check ICAP Service Status

Verify the ICAP service is running and accessible:

```bash
# Check if port is listening
podman exec squidclamav ss -tlnp | grep 1344

# Test connectivity and get version
podman exec squidclamav c-icap-client -i 127.0.0.1 -p 1344 -s squidclamav -V
```

### Test from Host Machine

If you've exposed the ICAP port (1344) when running the container:

```bash
# First, run container with exposed ports
podman run -d --name squidclamav -p 3128:3128 -p 1344:1344 squidclamav:latest

# Then test ICAP from your host (requires c-icap-client installed on host)
c-icap-client -i localhost -p 1344 -s squidclamav

# Or test through Squid proxy from host
curl -x http://localhost:3128 http://www.example.com
```

## Troubleshooting

### View Logs

```bash
podman logs -f squidclamav
```

### Check Service Status

```bash
podman exec squidclamav ps aux | grep -E "(squid|c-icap|clamav)"
```

### Check Listening Ports

```bash
podman exec squidclamav netstat -tlnp
# or (requires iproute2 package)
podman exec squidclamav ss -tlnp
```

Note: The `ss` command requires the `iproute2` package, which is included in the container.

### Verify Configuration

```bash
podman exec squidclamav cat /etc/c-icap/squidclamav.conf
podman exec squidclamav cat /etc/squid/squid.conf | grep icap
```

## Technical Details

- **Base Image**: Debian Bookworm (current stable)
- **SquidClamAV Version**: v7.4 (latest, from GitHub)
- **ClamAV Version**: 1.0.9 (from Debian Bookworm repositories)
- **c-icap Version**: 0.5.10 (from Debian Bookworm repositories)
- **Squid Version**: 5.7 (from Debian Bookworm repositories)

## Notes

- The container uses Debian Bookworm with current stable packages
- The entrypoint script handles runtime configuration and service startup
- All services run as root inside the container (consider security implications for production use)
- ClamAV database updates should work properly with the newer version

## License

This container setup is provided as-is. Please refer to the individual software licenses:
- Squid: GPL
- c-icap: LGPL
- SquidClamAV: GPL
- ClamAV: GPL
