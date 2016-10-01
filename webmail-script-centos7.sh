#!/bin/bash

clear
function intro () {
echo "
#######################################################################################################################
#                               This script written by abdelrahman tyson                                              #
#  This script is for fully installing and configring "WebMail" using {Postfix,Dovecot,SquirrelMail,with self sign SSL}  #
#                               Email: abdelrahman.ahmed306@yahoo.com                                                 #
#                                                                                                                     #
#######################################################################################################################
"
}
intro
sleep 2

#check root user
if [ $(id -u)  != "0" ]; then
    echo "Error: You have to run this script by user root!"
    exit
fi

#check internet connection
    echo "Check internet connection..."
    ping -c4 www.google.com > /dev/null 2> /dev/null
if [ $(echo $?) != "0" ]; then
    echo "there is no internet conncetion"
    echo "please check your internet connection before run this script"
	exit 1
else
    echo "done"
fi

#check OS : must be centos 7

#os=hostnamectl status  | grep -i operating | awk '{print $3$5}'

if [ "$(awk '{print $1}' /etc/redhat-release)" != "CentOS" -a  "$(cat /etc/redhat-release | cut -c22)" != "7" ]; then
    echo "Sorry, this script run on centos 7 only for now"
    echo "Wait for update soon"
    exit 1
fi

#check if configuration file exit for services

if [ -f /etc/squirrelmail/config.php -o -f /etc/dovecot/dovecot.conf ]; then
    echo "you have postfix or dovecot service already installed"
    echo "this script should run on new OS without installing any services before"
    exit 1
fi

#change your hostname

nhost="$(cat /etc/hostname)"
if [ $nhost == "localhost.localdomain" ]; then
    echo "You should change your hostname to looks like"
    echo "mail.tyson.org"
    read -p "enter Your new hostname: " nhost
    if [ -z $nhost ]; then
        echo "You did not write anything."
        echo "Sorry run the script again."
        exit 1
    else
        `hostnamectl set-hostname $nhost`
    fi
else
    echo "Your hostname is $nhost"
    read -p "change it [y/n]: " ch
    if [ -z $ch ]; then
        echo "sorry you did not choose anything, please run the script again."
    elif [ $ch == "y" -o $ch == "Y" ]; then
        read -p "The new hostname: " nhost
        `hostnamectl set-hostname $nhost`
    elif [ $ch == "n" -o $ch == "N" ]; then
        echo "You used your old hostname: $nhost"
    else
        echo "sorry you chose a wrong choice, please run the script again."
    fi
fi
    ndomain=`hostname | awk -F"." '{print $2"."$3}'`
###########################################################

#creating ssl self sign cert

function ssl () {
info_inputs="








"
    cd /etc/pki/tls/certs/
    echo "Please enter the pass phrase by yourself"
    make server.key
    echo "Please enter the same passphrase you enterd before"
    openssl rsa -in server.key -out server.key
{
    make server.csr <<< "${info_inputs}"
} > /dev/null 2>&1
    openssl x509 -in server.csr -out server.crt -req -signkey server.key -days 3650 > /dev/null 2>&1
    cd
}

ssl 

###########################################################
#installing epel repo

	echo "installing epel repo .............."
#	rm -f /etc/yum.repos.d/epel* > /dev/null 2>&1
	yum clean all
	yum -y install epel-release  

#install some services

	echo "installing some services packages .............."
	yum -y install postfix dovecot php php-mbstring php-pear httpd mod_ssl squirrelmail > /dev/null 2>&1

#get some SquirrelMail plugins
{
	wget http://www.squirrelmail.org/plugins/compatibility-2.0.16-1.0.tar.gz
	wget http://www.squirrelmail.org/plugins/empty_trash-2.0-1.2.2.tar.gz
	wget http://www.squirrelmail.org/plugins/secure_login-1.4-1.2.8.tar.gz
	tar zxvf compatibility-2.0.16-1.0.tar.gz -C /usr/share/squirrelmail/plugins
	tar zxvf empty_trash-2.0-1.2.2.tar.gz -C /usr/share/squirrelmail/plugins
	tar zxvf secure_login-1.4-1.2.8.tar.gz -C /usr/share/squirrelmail/plugins
	rm -f compatibility-2.0.16-1.0.tar.gz
	rm -f empty_trash-2.0-1.2.2.tar.gz
	rm -f secure_login-1.4-1.2.8.tar.gz
} > /dev/null 2>&1

#change configuration file for services.

#configuration for dovecort service

    timezone1=`timedatectl status | grep -i timezone | awk '{print $2}' | awk -F"/" '{print $1}'`
    timezone2=`timedatectl status | grep -i timezone | awk '{print $2}' | awk -F"/" '{print $2}'`
    sed -i 's/^;date.timezone =/date.timezone = '$timezone1'\/'$timezone2'/' /etc/php.ini
    sed -i '24s/#//' /etc/dovecot/dovecot.conf
    sed -i '30s/#//' /etc/dovecot/dovecot.conf
	sed -i '30s/, :://' /etc/dovecot/dovecot.conf #configre to work with IPV4 only and accept login from all IPS (not secure)
    sed -i -e '10s/#//;10s/yes/no/' /etc/dovecot/conf.d/10-auth.conf
    sed -i '100s/plain/plain login/' /etc/dovecot/conf.d/10-auth.conf
    sed -i -e '30s/#//;30s/=/= maildir:~\/Maildir/' /etc/dovecot/conf.d/10-mail.conf
    sed -i -e '96s/#//;97s/#//;98s/#//' /etc/dovecot/conf.d/10-master.conf
    sed -i '97a user = postfix' /etc/dovecot/conf.d/10-master.conf
    sed -i '98a group = postfix' /etc/dovecot/conf.d/10-master.conf
    sed -i '8s/required/no/' /etc/dovecot/conf.d/10-ssl.conf
    echo "Dovecort configuration done."
###################################################################################################


#configuration for postfix service

    sed -i '75s/#myhostname.*/myhostname = '$nhost'/' /etc/postfix/main.cf
    sed -i 's/#mydomain.*/mydomain = '$ndomain'/' /etc/postfix/main.cf
    sed -i '99s/#//' /etc/postfix/main.cf
    sed -i '116s/localhost/all/' /etc/postfix/main.cf
    sed -i 164d /etc/postfix/main.cf
    sed -i '164s/#//' /etc/postfix/main.cf
    sed -i '263s/#//' /etc/postfix/main.cf
    sed -i '263s/168.100.189.0/192.168.0.0/' /etc/postfix/main.cf #change if your ip range not start with 192.168.
    sed -i '263s/\/28/\/24/' /etc/postfix/main.cf
    sed -i '418s/#//' /etc/postfix/main.cf
    sed -i '571s/#//' /etc/postfix/main.cf
    sed -i '571s/$mail_name//' /etc/postfix/main.cf

    echo "
# for SMTP-Auth

smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = \$myhostname
smtpd_recipient_restrictions = permit_mynetworks,permit_auth_destination,permit_sasl_authenticated,reject" >> /etc/postfix/main.cf
    echo "Postfix configuration done."

#   Create own-created SSL Certificates

#some input information for making the cert
#######################

#   Configure SSL to use secure encrypt connection
    sed -i '59s/#//' /etc/httpd/conf.d/ssl.conf
    sed -i '60s/#ServerName.*/ServerName www.'$ndomain':443/' /etc/httpd/conf.d/ssl.conf
    sed -i '75s/SSLProtocol.*/SSLProtocol -All +TLSv1 +TLSv1.1 +TLSv1.2/' /etc/httpd/conf.d/ssl.conf
    sed -i '100s/SSLCertificateFile.*/SSLCertificateFile \/etc\/pki\/tls\/certs\/server.crt/' /etc/httpd/conf.d/ssl.conf
    sed -i '107s/SSLCertificateKeyFile.*/SSLCertificateKeyFile \/etc\/pki\/tls\/certs\/server.key/' /etc/httpd/conf.d/ssl.conf

#    echo "
#Alias /webmail /usr/share/squirrelmail
#<Directory /usr/share/squirrelmail>
#Options Indexes FollowSymLinks
#RewriteEngine On
#AllowOverride All
#DirectoryIndex index.php
#Order allow,deny
#Allow from all
#</Directory>" >> /etc/httpd/conf/httpd.conf
    echo "http & SSL configuration done."

#enabling and start servics

    echo "starting and enabling services..."
{
    systemctl restart httpd
    systemctl enable httpd
    systemctl restart postfix
    systemctl enable postfix
    systemctl restart dovecot
    systemctl enable dovecot
} > /dev/null 2>&1
    echo "done"

#open firewalld ports
    echo "opening some firewalld ports..."
{    
    firewall-cmd --add-service=https --permanent 
    firewall-cmd --add-port={110/tcp,143/tcp} --permanent #for POP3 & IMAP
    firewall-cmd --add-service=smtp --permanent
    firewall-cmd --reload
} > /dev/null 2>&1

    echo "done"

all_inputs="1
5 
/webmail
r
2
1
$ndomain
3
2
A
4
$nhost
8
dovecot
9
detect
B
4
$nhost
7
n
login
n
r
4
7
y
r
8
7
8
15
q
y
"
{
/usr/share/squirrelmail/config/conf.pl <<< "${all_inputs}"
} > /dev/null 2>&1
    cp /usr/share/squirrelmail/plugins/secure_login/config.sample.php /usr/share/squirrelmail/plugins/secure_login/config.php

    sed -i '24s/1/0/' /usr/share/squirrelmail/plugins/secure_login/config.php 

#selinux
    setsebool -P httpd_can_network_connect on 

    systemctl restart httpd
    IP=`hostname -I | awk '{print $1}'`
    echo "$IP $nhost $ndomain" >> /etc/hosts

clear


intro #the intro function

echo ""
echo ""
echo "                                  congratulations
                                everything done successfully
                now you can login by writting the link below in your browser 
                       
            ##################################################################
            #                     https://$IP/webmail                #
            ##################################################################

NOW login with any username and it's password  you have on your system or you can add more users and loging by them too."

#The END
