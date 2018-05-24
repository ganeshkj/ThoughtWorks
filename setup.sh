#!/bin/bash

## COLORS
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

## Variables
TF_URL="https://releases.hashicorp.com/terraform/0.11.7/terraform_0.11.7_linux_amd64.zip"
TF_ZIP_FILE=$(echo $TF_URL | awk -F / '{print $NF}')  # echo $CONN_URL | awk -F / '{print $NF}'

ULOCAL_BIN_PATH="/usr/local/bin/"

YUM_CMD=$(which yum)
APT_GET_CMD=$(which apt-get)
TF_CMD=$(which terraform)
ANS_CMD=$(which ansible)
UNZIP_CMD=$(which unzip)

PKG=""

##
LOG=/tmp/stack
rm -f /tmp/stack

if [[ ! -z $YUM_CMD ]]; then
PKG="YUM"
elif [[ ! -z $APT_GET_CMD ]]; then
PKG="APT"
else
echo "Script Work's Only on Debian & RPM based machine's"
exit 1;
fi


## FUnctions

INSTALL(){
	if [[ $PKG == "YUM" ]]; then
		yum install -y $1 &>>$LOG
	elif [[ $PKG == "APT" ]]; then
		apt-get install -y $1 &>>$LOG
	else
		echo -e "$R Unable to Find the System Pacakge manager $N"
	fi
}

VALIDATE() {
	if [ $1 -eq 0 ]; then 
		echo -e "$2 .. $G SUCCESS $N"
	else
		echo -e "$2 .. $R FAILURE $N"
		exit 1
	fi
}

SKIP() {
	echo -e "$1 .. $Y SKIPPING $N"
}


############
ID=`id -u`
if [ $ID -ne 0 ]; then 
	echo -e " $R You Should be root user to perform this Script $N"
	exit 2
fi

 
if [[ -z $UNZIP_CMD ]]; then
	INSTALL unzip
	VALIDATE $? "Installing Unzip"
else
	SKIP "Installing Unzip"
fi

if [[ -z $TF_CMD ]]; then
	rm -f $TF_ZIP_FILE*
	wget $TF_URL && unzip $TF_ZIP_FILE -d $ULOCAL_BIN_PATH &>>$LOG
	VALIDATE $? "Installing terraform"
	rm -f $TF_ZIP_FILE
else
	SKIP "Installing terraform"
fi

if [[ -z $ANS_CMD ]]; then
	if [[ $PKG = "APT" ]]; then
		echo "Adding Ansible Repo and refreshing"
		apt-add-repository -y ppa:ansible/ansible &>>$LOG
		apt-get update &>>$LOG
	fi
	INSTALL ansible
	VALIDATE $? "Installing Ansible"
else
	SKIP "Installing Ansible"
fi


read -p "Enter Your AWS ACCESS KEY ID : "  AWS_KEY_ID
echo ""
read -p "Enter Your AWS SECRET ACCESS KEY : "  AWS_SECRET

export AWS_ACCESS_KEY_ID=$(echo $AWS_KEY_ID) AWS_SECRET_ACCESS_KEY=$(echo "$AWS_SECRET")

echo -e "$Y Running terraform to intiate Instances on AWS $N"
cd terraform
terraform init &>>$LOG
VALIDATE $? "Intiating terraform"

terraform import aws_key_pair.CompanyNewsKey companynews-key &>>$LOG

#create Directory for SSH keys
mkdir -p ../.ssh

read -s -p "Please enter the Passphrase (Leave Empty for None): " SKPASS_1

read -s -p "Please reenter the Passphrase (Leave Empty for None): " SKPASS_2

if [[ $SKPASS_1 == $SKPASS_2 ]]; then
	#Generate SSH Keys
	ssh-keygen -t rsa -b 4096 -C "ubuntu" -P "$SKPASS_1" -f ../.ssh/id_rsa -q
	VALIDATE $? "Generating new SSH Key"
else
	echo -e "$R Passphrase Didn't Match"
	exit 2
fi

terraform apply -auto-approve . &>>$LOG
VALIDATE $? "Applying terraform template"

if [ $? -eq 0 ]; then
	APP_SERV_IP=$(terraform output | grep "CompanyNewsAppl" | cut -d "=" -f2 | sed "s/\ //")
	WEB_SERV_IP=$(terraform output | grep "CompanyNewsWeb" | cut -d "=" -f2 | sed "s/\ //")
	cd ..
echo "[WEB]
$WEB_SERV_IP

[APP]
$APP_SERV_IP" > ansible/inventory
else
	echo -e "$R error with terraform $N"
	exit 2
fi

# cd terraform
# APP_SERV_IP=$(terraform output | grep "CompanyNewsAppl" | cut -d "=" -f2 | sed "s/\ //")
# WEB_SERV_IP=$(terraform output | grep "CompanyNewsWeb" | cut -d "=" -f2 | sed "s/\ //")
# cd ..

ssh -q -o UserKnownHostsFile=/dev/null -i .ssh/id_rsa -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$APP_SERV_IP sudo apt-get install -y python &>>$LOG
ssh -q -o UserKnownHostsFile=/dev/null -i .ssh/id_rsa -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$WEB_SERV_IP sudo apt-get install -y python &>>$LOG

cd ansible

echo -e "$Y Configuring Web Server $N"
ansible-playbook -l WEB web.yml &>>$LOG
VALIDATE $? "Setting Up Web Server"

echo -e "$Y Configuring Application Server $N"
ansible-playbook -l APP application.yml &>>$LOG
VALIDATE $? "Setting Up Application Server"

echo -e "$G open https://$WEB_SERV_IP/companyNews $N"