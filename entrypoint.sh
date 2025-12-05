#!/bin/bash

# ============================================================================
# Section 1: Install all required packages
# ============================================================================
echo "=== Installing required packages ==="
apt-get update
apt-get install -y vim
apt-get install -y squid
apt-get install -y patch
apt-get install -y libicapapi-dev
apt-get install -y libc-dev
apt-get install -y file
apt-get install -y wget
apt-get install -y gcc
apt-get install -y ca-certificates
apt-get install -y make
apt-get install -y libicapapi5
apt-get install -y libbz2-dev
apt-get install -y zlib1g-dev
apt-get install -y git
apt-get install -y clamav clamav-daemon
apt-get install -y net-tools

# ============================================================================
# Section 2: Configure Squid
# ============================================================================
echo "=== Configuring Squid ==="
echo "icap_enable on" >> /etc/squid/squid.conf
echo "icap_send_client_ip on" >> /etc/squid/squid.conf
echo "icap_send_client_username on" >> /etc/squid/squid.conf
echo "icap_client_username_encode off" >> /etc/squid/squid.conf
echo "icap_client_username_header X-Authenticated-User" >> /etc/squid/squid.conf
echo "icap_preview_enable on" >> /etc/squid/squid.conf
echo "icap_preview_size 1024" >> /etc/squid/squid.conf
echo "icap_service service_avi_req reqmod_precache icap://127.0.0.1:1344/squidclamav bypass=off" >> /etc/squid/squid.conf
echo "adaptation_access service_avi_req allow all" >> /etc/squid/squid.conf
echo "icap_service service_avi_resp respmod_precache icap://127.0.0.1:1344/squidclamav bypass=on" >> /etc/squid/squid.conf
echo "adaptation_access service_avi_resp allow all" >> /etc/squid/squid.conf

# ============================================================================
# Section 3: Configure c-icap
# ============================================================================
echo "=== Configuring c-icap ==="
echo "Service squidclamav squidclamav.so" >> /etc/c-icap/c-icap.conf
sed -i 's/^enable_libarchive /#enable_libarchive /' /etc/c-icap/squidclamav.conf || true
sed -i 's/^banmaxsize /#banmaxsize /' /etc/c-icap/squidclamav.conf || true

# ============================================================================
# Section 4: Build and install SquidClamAV
# ============================================================================
echo "=== Building and installing SquidClamAV ==="
rm -rf /usr/lib/x86_64-linux-gnu/c_icap/squidclamav.la
rm -rf /usr/lib/x86_64-linux-gnu/c_icap/squidclamav.so
mkdir -p /opt/csw/
git clone --recursive https://github.com/darold/squidclamav.git "/usr/src/squidclamav"
cd /usr/src/squidclamav
git checkout v7.4 2>/dev/null || true
./configure --with-c-icap=/etc/c-icap --with-libarchive=/opt/csw/
make
make install

# ============================================================================
# Section 5: Setup ClamAV
# ============================================================================
echo "=== Setting up ClamAV ==="
# Create clamav user if it doesn't exist
if ! id -u clamav >/dev/null 2>&1; then
    useradd -r -s /bin/false -d /var/lib/clamav clamav
fi
# Ensure directory exists and has correct permissions
mkdir -p /var/lib/clamav
chown clamav:clamav /var/lib/clamav
# Update ClamAV database using freshclam
freshclam || true
chown -R clamav:clamav /var/lib/clamav/
chmod -R 755 /var/lib/clamav/
# Download EICAR test file
wget --no-check-certificate https://secure.eicar.org/eicar_com.zip

# ============================================================================
# Section 6: Start services
# ============================================================================
echo "=== Starting services ==="
mkdir -p /var/run/c-icap
chown c-icap:c-icap /var/run/c-icap

# Start Squid (using systemctl if available, otherwise direct)
if command -v systemctl >/dev/null 2>&1; then
    systemctl start squid || /usr/sbin/squid -YC -f /etc/squid/squid.conf
else
    /usr/sbin/squid -YC -f /etc/squid/squid.conf
fi

# Start c-icap
c-icap -d 10 -f /etc/c-icap/c-icap.conf

# ============================================================================
# Section 7: Keep container running
# ============================================================================
echo "=== All services started. Container is ready. ==="
echo "=== Squid proxy: port 3128 ==="
echo "=== c-icap service: port 1344 ==="
echo "=== Container will keep running. Use 'podman logs -f squidclamav' to view logs. ==="
# Keep container running (this is intentional - container should stay alive)
tail -f /dev/null
