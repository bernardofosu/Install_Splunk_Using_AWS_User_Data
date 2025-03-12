#!/bin/bash

# 1️⃣ Update OS and Install Required Packages
apt-get update -y
apt-get install -y \
    bc \
    net-tools \
    ncat \
    socat \
    nethogs \
    htop \
    vim \
    sysstat \
    nano \
    git \
    chrony \
    rsync \
    acl \
    cowsay

# 2️⃣ Create Splunk Forwarder User with Limited Permissions
id -u splunkfwd &>/dev/null || useradd -m -s /bin/false splunkfwd

# 3️⃣ Setup Splunk Directory and Permissions
mkdir -p /opt/splunkforwarder
chown -R splunkfwd:splunkfwd /opt/splunkforwarder
chmod -R 750 /opt/splunkforwarder

# 4️⃣ Download and Install Splunk Universal Forwarder
SPLUNK_TAR="/tmp/splunkforwarder-9.1.6-a28f08fac354-Linux-x86_64.tgz"
if [ ! -f "$SPLUNK_TAR" ]; then
  wget -O "$SPLUNK_TAR" "https://download.splunk.com/products/universalforwarder/releases/9.1.6/linux/splunkforwarder-9.1.6-a28f08fac354-Linux-x86_64.tgz"
fi

tar -xzvf "$SPLUNK_TAR" -C /opt
mv /opt/splunkforwarder-* /opt/splunkforwarder
sudo usermod -s /bin/bash splunkfwd

# 5️⃣ Configure Splunk Forwarder with Minimal Permissions
chown -R splunkfwd:splunkfwd /opt/splunkforwarder
chmod -R 750 /opt/splunkforwarder

# 6️⃣ Enable Splunk Forwarder Boot-Start
sudo /opt/splunkforwarder/bin/splunk enable boot-start -user splunkfwd --accept-license --answer-yes --no-prompt

# 7️⃣ Configure Splunk Forwarder SSL and Deployment Server
cat > /opt/splunkforwarder/etc/system/local/server.conf << EOF
[sslConfig]
sslVersions = tls1.2
EOF

# 8️⃣ Start Splunk Forwarder
sudo /opt/splunkforwarder/bin/splunk start

# 9️⃣ Display Success Message
echo 'export PATH=$PATH:/usr/games' >> ~/.bashrc
source ~/.bashrc
/usr/games/cowsay -f tux "Splunk Forwarder installed successfully!"
