# we need 3 parameters: domain, username, password, computer_name, sudoers, domain_ip_address, domain_controller
# We intialize vars
domain="$1"
username="$2"
password="$3"
computer_name="$4"
domain_ip_address="$6"
domain_controller="$7"
sudoers=("${!5}")

# we install the necessary packages
sudo apt update -y
sudo apt upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt -y install krb5-user realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin oddjob oddjob-mkhomedir packagekit

# we delete krb5.conf
sudo rm /etc/krb5.conf 

# we fill the krb5.conf using cat
sudo cat <<EOF > /etc/krb5.conf
[libdefaults]
default_realm = $domain
[realms]
$domain = {
    kdc = $domain_ip_address
    admin_server = $domain_ip_address
}
[domain_realm]
.$(echo $domain | tr '[:upper:]' '[:lower:]') = $domain
EOF

# we set proper permissions for krb5.conf
sudo chmod 644 /etc/krb5.conf

# we set the hostname
hostnamectl set-hostname $computer_name.$domain

# we join the domain
sudo adcli join --domain=$(echo $domain | tr '[:upper:]' '[:lower:]') --domain-controller=$domain_controller --login-user=$username --show-details --stdin-password <<EOF
$password
EOF

# we delete sssd.conf
sudo rm /etc/sssd/sssd.conf

# we fill the sssd.conf using cat
sudo cat <<EOF > /etc/sssd/sssd.conf
[sssd]
domains = $(echo $domain | tr '[:upper:]' '[:lower:]')
config_file_version = 2
services = nss, pam

[domain/$(echo $domain | tr '[:upper:]' '[:lower:]')]
default_shell = /bin/bash
ad_server = $domain_controller
krb5_store_password_if_offline = True
cache_credentials = True
krb5_realm = $domain
realmd_tags = manages-system joined-with-adcli
id_provider = ad
fallback_homedir = /home/%u@%d
ad_domain = $(echo $domain | tr '[:upper:]' '[:lower:]')
use_fully_qualified_names = False
ldap_id_mapping = True
access_provider = ad
ad_gpo_access_control = disabled
dyndns_update = True
ad_hostname = $computer_name.$domain
EOF

#  we set the permissions of sssd.conf
sudo chmod 600 /etc/sssd/sssd.conf

# we restart the sssd service
sudo systemctl restart sssd

# we create the home directory
sudo pam-auth-update --enable mkhomedir

# we add sudoers to /etc/sudoers.d/shift_sudoers
rm /etc/sudoers.d/shift_sudoers
sudo touch /etc/sudoers.d/shift_sudoers
for i in "${sudoers[@]}";
do
    sudo echo "%$i ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/shift_sudoers
done