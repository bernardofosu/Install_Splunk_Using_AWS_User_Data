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
    rsync

# 2️⃣ Setup Crontab to Delete Old Logs Every Hour
crontab -l > mycron 2>/dev/null || true
echo "0 */1 * * * /usr/bin/find /opt/syslog/ -type d -ctime +2 -exec rm -rf {} \;" >> mycron
crontab mycron
rm -f mycron

# 3️⃣ Configure Bash History to Include Timestamps
echo "export HISTTIMEFORMAT=\"%F %T \"" | sudo tee -a /etc/profile.d/sdaedu.sh && source /etc/profile.d/sdaedu.sh

# 4️⃣ Configure User Session Timeout
cat >> /etc/bashrc << 'EOF'
TMOUT=300
readonly TMOUT
export TMOUT
EOF

# 5️⃣ Ensure Default Shell is Bash in Useradd Command
sudo sed -i '/^SHELL=/d' /etc/default/useradd
sudo sed -i '8iSHELL=/bin/bash' /etc/default/useradd

# 6️⃣ Create Users if They Don't Exist
id -u splunk &>/dev/null || sudo useradd -m splunk
id -u atlgsdachedu &>/dev/null || sudo useradd -m atlgsdachedu
sudo usermod -a -G splunk atlgsdachedu
sudo chage -M -1 atlgsdachedu

echo "atlgsdachedu ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/atlgsdachedu
echo "splunk ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/splunk

# 7️⃣ Revert Default Shell to Sh
sudo sed -i '/^SHELL=/d' /etc/default/useradd
sudo sed -i '8iSHELL=/bin/sh' /etc/default/useradd

# 8️⃣ Set Password Requirements
echo "minlen = 8" | sudo tee -a /etc/security/pwquality.conf

# 9️⃣ Update System Resource Limits
sudo cp /etc/systemd/system.conf /etc/systemd/system.conf.bak
sudo sed -i 's/^#DefaultLimitNOFILE=.*/DefaultLimitNOFILE=64000/' /etc/systemd/system.conf
sudo sed -i 's/^#DefaultLimitNPROC=.*/DefaultLimitNPROC=16000/' /etc/systemd/system.conf
sudo sed -i 's/^#DefaultTasksMax=.*/DefaultTasksMax=80%/' /etc/systemd/system.conf

# 🔟 Disable Transparent Huge Pages (THP)
echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo 'never' | sudo tee /sys/kernel/mm/transparent_hugepage/defrag
grub2-editenv - set "$(grub2-editenv - list | grep kernelopts) transparent_hugepage=never"

# 1️⃣1️⃣ Setup Splunk Directory
sudo mkdir -p /opt/splunk
sudo chown -R splunk:splunk /opt/splunk

# 1️⃣2️⃣ Set File Permissions
sudo apt install -y acl
sudo setfacl -Rdm u:splunk:rX /var/log/
sudo setfacl -Rm "u:splunk:r-X" /var/log/

# 1️⃣3️⃣ Message of the Day (MOTD) Setup
echo "ritaedu Splunk Build" | sudo tee /etc/motd.d/sdaedu

# 1️⃣4️⃣ Enable and Start Chrony Time Sync
sudo systemctl enable chrony
sudo systemctl start chrony

# 1️⃣5️⃣ Set SPLUNK_HOME Environment Variable
echo 'export SPLUNK_HOME="/opt/splunk"' | sudo tee -a /etc/profile.d/splunk.sh
source /etc/profile.d/splunk.sh

# 1️⃣6️⃣ Create Splunk Admin Seed File
sudo bash -c 'cat > /tmp/user-seed.conf << EOF
[user_info]
USERNAME = admin
PASSWORD = splunk123
EOF'
sudo chmod 600 /tmp/user-seed.conf

# 1️⃣7️⃣ Download Splunk TAR File (If Not Exists)
if [ ! -f /tmp/splunk-9.1.6-a28f08fac354-Linux-x86_64.tgz ]; then
  wget -O /tmp/splunk-9.1.6-a28f08fac354-Linux-x86_64.tgz "https://download.splunk.com/products/splunk/releases/9.1.6/linux/splunk-9.1.6-a28f08fac354-Linux-x86_64.tgz"
fi

# 1️⃣8️⃣ Extract Splunk to /opt
sudo tar -xzvf /tmp/splunk-9.1.6-a28f08fac354-Linux-x86_64.tgz -C /opt

# 1️⃣9️⃣ Move Configuration Files
sudo mv /tmp/user-seed.conf $SPLUNK_HOME/etc/system/local/user-seed.conf
sudo touch $SPLUNK_HOME/etc/.ui_login
sudo chown -R splunk:splunk $SPLUNK_HOME

# 2️⃣0️⃣ Enable Splunk Boot-Start
sudo -u splunk $SPLUNK_HOME/bin/splunk enable boot-start -user splunk --accept-license --answer-yes --no-prompt

# 2️⃣1️⃣ Configure Splunk Web to Use SSL
echo -e "[settings]\nstartwebserver = True\nenableSplunkWebSSL = True\nsslVersions = tls1.2\n" | sudo tee -a $SPLUNK_HOME/etc/system/local/web.conf

# 2️⃣2️⃣ Start Splunk
sudo -u splunk $SPLUNK_HOME/bin/splunk start

# 2️⃣5️⃣ Display Success Message (No Need Here)
sudo apt install -y cowsay
echo 'export PATH=$PATH:/usr/games' >> ~/.bashrc
source ~/.bashrc
/usr/games/cowsay -f tux "WoHoo..Welcome to ATLGSDACH EDU..You installed SPLUNK successfully"
echo "done"
