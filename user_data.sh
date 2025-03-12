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

# 2️⃣ Setup Crontab to Delete Old Logs Every Hour
(crontab -l 2>/dev/null; echo "0 */1 * * * /usr/bin/find /opt/syslog/ -type d -ctime +2 -exec rm -rf {} \;") | crontab -

# 3️⃣ Configure Bash History to Include Timestamps
echo "export HISTTIMEFORMAT=\"%F %T \"" | tee -a /etc/profile.d/sdaedu.sh
chmod +x /etc/profile.d/sdaedu.sh

# 4️⃣ Configure User Session Timeout
cat >> /etc/bashrc << 'EOF'
TMOUT=300
readonly TMOUT
export TMOUT
EOF

# 5️⃣ Ensure Default Shell is Bash in Useradd Command
sed -i '/^SHELL=/d' /etc/default/useradd
sed -i '8iSHELL=/bin/bash' /etc/default/useradd

# 6️⃣ Create Users if They Don't Exist
id -u splunk &>/dev/null || useradd -m splunk
id -u atlgsdachedu &>/dev/null || useradd -m atlgsdachedu
usermod -a -G splunk atlgsdachedu
chage -M -1 atlgsdachedu
echo "atlgsdachedu ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/atlgsdachedu
echo "splunk ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/splunk

# 7️⃣ Revert Default Shell to Sh
sed -i '/^SHELL=/d' /etc/default/useradd
sed -i '8iSHELL=/bin/sh' /etc/default/useradd

# 8️⃣ Set Password Requirements
echo "minlen = 8" | tee -a /etc/security/pwquality.conf

# 9️⃣ Update System Resource Limits
cp /etc/systemd/system.conf /etc/systemd/system.conf.bak
sed -i 's/^#DefaultLimitNOFILE=.*/DefaultLimitNOFILE=64000/' /etc/systemd/system.conf
sed -i 's/^#DefaultLimitNPROC=.*/DefaultLimitNPROC=16000/' /etc/systemd/system.conf
sed -i 's/^#DefaultTasksMax=.*/DefaultTasksMax=80%/' /etc/systemd/system.conf

# 🔟 Disable Transparent Huge Pages (THP)
echo 'never' | tee /sys/kernel/mm/transparent_hugepage/enabled
echo 'never' | tee /sys/kernel/mm/transparent_hugepage/defrag
if command -v grub2-editenv &>/dev/null; then
grub2-editenv - set "$(grub2-editenv - list | grep kernelopts) transparent_hugepage=never"
fi

# 1️⃣1️⃣ Setup Splunk Directory
mkdir -p /opt/splunk
chown -R splunk:splunk /opt/splunk

# 1️⃣2️⃣ Set File Permissions
setfacl -Rdm u:splunk:rX /var/log/
setfacl -Rm "u:splunk:r-X" /var/log/

# 1️⃣3️⃣ Message of the Day (MOTD) Setup
mkdir -p /etc/motd.d/
echo "ritaedu Splunk Build" | tee /etc/motd.d/sdaedu

# 1️⃣4️⃣ Enable and Start Chrony Time Sync
systemctl enable chrony
systemctl start chrony

# 1️⃣5️⃣ Set SPLUNK_HOME Environment Variable
echo 'export SPLUNK_HOME="/opt/splunk"' | tee -a /etc/profile.d/splunk.sh
chmod +x /etc/profile.d/splunk.sh

# 1️⃣6️⃣ Create Splunk Admin Seed File
cat > /tmp/user-seed.conf << EOF
[user_info]
USERNAME = admin
PASSWORD = splunk123
EOF
chmod 600 /tmp/user-seed.conf

# 1️⃣7️⃣ Download Splunk TAR File (If Not Exists)
SPLUNK_TAR="/tmp/splunk-9.1.6-a28f08fac354-Linux-x86_64.tgz"
if [ ! -f "$SPLUNK_TAR" ]; then
  wget -O "$SPLUNK_TAR" "https://download.splunk.com/products/splunk/releases/9.1.6/linux/splunk-9.1.6-a28f08fac354-Linux-x86_64.tgz"
fi

# 1️⃣8️⃣ Extract Splunk to /opt
tar -xzvf "$SPLUNK_TAR" -C /opt
mv /opt/splunk-* /opt/splunk

# 1️⃣9️⃣ Move Configuration Files
mv /tmp/user-seed.conf /opt/splunk/etc/system/local/user-seed.conf
touch /opt/splunk/etc/.ui_login
chown -R splunk:splunk /opt/splunk

# 2️⃣0️⃣ Enable Splunk Boot-Start
sudo /opt/splunk/bin/splunk enable boot-start -user splunk --accept-license --answer-yes --no-prompt

# 2️⃣1️⃣ Configure Splunk Web to Use SSL
echo -e "[settings]\nstartwebserver = True\nenableSplunkWebSSL = True\nsslVersions = tls1.2\n" | tee -a /opt/splunk/etc/system/local/web.conf
sudo /opt/splunk/bin/splunk restart

# 2️⃣2️⃣ Start Splunk
sudo /opt/splunk/bin/splunk start
# note: splunk is currently running, please stop it before running enable/disable boot-start

# 2️⃣3️⃣ Display Success Message
echo 'export PATH=$PATH:/usr/games' >> ~/.bashrc
source ~/.bashrc
/usr/games/cowsay -f tux "WoHoo..Welcome to ATLGSDACH EDU..You installed SPLUNK successfully"
echo "done"
