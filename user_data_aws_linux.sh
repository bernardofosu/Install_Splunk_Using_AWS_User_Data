#!/bin/bash

set -e  # Exit on error

# 1️⃣ Update System and Install Required Packages
echo "[INFO] Updating system and installing dependencies..."
dnf update -y
dnf install -y \
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

# 2️⃣ Setup Cronjob for Log Cleanup
echo "[INFO] Setting up log cleanup cronjob..."
(crontab -l 2>/dev/null; echo "0 * * * * /usr/bin/find /opt/syslog/ -type d -ctime +2 -exec rm -rf {} \;") | crontab -

# 3️⃣ Configure Bash History to Include Timestamps
echo "export HISTTIMEFORMAT=\"%F %T \"" | tee -a /etc/profile.d/splunk_env.sh
chmod +x /etc/profile.d/splunk_env.sh

# 4️⃣ Set User Session Timeout
cat >> /etc/bashrc << 'EOF'
TMOUT=300
readonly TMOUT
export TMOUT
EOF

# 5️⃣ Configure Default Shell for Users
sed -i '/^SHELL=/d' /etc/default/useradd
sed -i '8iSHELL=/bin/bash' /etc/default/useradd

# 6️⃣ Create Splunk User if Not Exists
id -u splunk &>/dev/null || useradd -m -s /bin/bash splunk
echo "splunk ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/splunk

# 7️⃣ Restore Default Shell to `sh`
sed -i '/^SHELL=/d' /etc/default/useradd
sed -i '8iSHELL=/bin/sh' /etc/default/useradd

# 8️⃣ Set Password Security Policy
echo "minlen = 8" | tee -a /etc/security/pwquality.conf

# 9️⃣ Configure System Resource Limits
echo "[INFO] Setting system resource limits..."
cp /etc/systemd/system.conf /etc/systemd/system.conf.bak
sed -i 's/^#DefaultLimitNOFILE=.*/DefaultLimitNOFILE=64000/' /etc/systemd/system.conf
sed -i 's/^#DefaultLimitNPROC=.*/DefaultLimitNPROC=16000/' /etc/systemd/system.conf
sed -i 's/^#DefaultTasksMax=.*/DefaultTasksMax=80%/' /etc/systemd/system.conf

# 🔟 Disable Transparent Huge Pages (THP)
echo "[INFO] Disabling Transparent Huge Pages..."
echo 'never' | tee /sys/kernel/mm/transparent_hugepage/enabled
echo 'never' | tee /sys/kernel/mm/transparent_hugepage/defrag
if command -v grub2-editenv &>/dev/null; then
  grub2-editenv - set "$(grub2-editenv - list | grep kernelopts) transparent_hugepage=never"
fi

# 1️⃣1️⃣ Create Splunk Directory
mkdir -p /opt/splunk
chown -R splunk:splunk /opt/splunk

# 1️⃣2️⃣ Set File Permissions for Logs
setfacl -Rdm u:splunk:rX /var/log/
setfacl -Rm "u:splunk:r-X" /var/log/

# 1️⃣3️⃣ Configure MOTD (Message of the Day)
mkdir -p /etc/motd.d/
echo "Welcome to Splunk Enterprise on Amazon Linux!" | tee /etc/motd.d/splunk_motd

# 1️⃣4️⃣ Enable & Start Chrony Time Sync
systemctl enable chronyd
systemctl start chronyd

# 1️⃣5️⃣ Set SPLUNK_HOME Environment Variable
echo 'export SPLUNK_HOME="/opt/splunk"' | tee -a /etc/profile.d/splunk.sh
chmod +x /etc/profile.d/splunk.sh

# 1️⃣6️⃣ Create Splunk Admin User Seed File
cat > /tmp/user-seed.conf << EOF
[user_info]
USERNAME = admin
PASSWORD = splunk123
EOF
chmod 600 /tmp/user-seed.conf

# 1️⃣7️⃣ Download Splunk TAR File (If Not Exists)
SPLUNK_VERSION="9.1.6"
SPLUNK_BUILD="a28f08fac354"
SPLUNK_TAR="/tmp/splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-Linux-x86_64.tgz"
SPLUNK_URL="https://download.splunk.com/products/splunk/releases/${SPLUNK_VERSION}/linux/splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-Linux-x86_64.tgz"

if [ ! -f "$SPLUNK_TAR" ]; then
  echo "[INFO] Downloading Splunk Enterprise..."
  wget -O "$SPLUNK_TAR" "$SPLUNK_URL"
fi

# 1️⃣8️⃣ Extract Splunk to /opt
echo "[INFO] Extracting Splunk Enterprise..."
tar -xzf "$SPLUNK_TAR" -C /opt
mv /opt/splunk-* /opt/splunk

# 1️⃣9️⃣ Move Configuration Files
mv /tmp/user-seed.conf /opt/splunk/etc/system/local/user-seed.conf
touch /opt/splunk/etc/.ui_login
chown -R splunk:splunk /opt/splunk

# 2️⃣0️⃣ Enable Splunk Boot-Start
echo "[INFO] Enabling Splunk at boot..."
sudo -u splunk /opt/splunk/bin/splunk enable boot-start -user splunk --accept-license --answer-yes --no-prompt

# 2️⃣1️⃣ Configure Splunk Web to Use SSL
cat > /opt/splunk/etc/system/local/web.conf << EOF
[settings]
startwebserver = True
enableSplunkWebSSL = True
sslVersions = tls1.2
EOF

# 2️⃣2️⃣ Start Splunk
echo "[INFO] Starting Splunk Enterprise..."
sudo -u splunk /opt/splunk/bin/splunk start

# 2️⃣3️⃣ Success Message
echo 'export PATH=$PATH:/usr/games' >> ~/.bashrc
source ~/.bashrc
/usr/games/cowsay -f tux "WoHoo..Welcome to Splunk Enterprise on Amazon Linux!"
echo "[SUCCESS] Splunk Enterprise is installed and running!"
