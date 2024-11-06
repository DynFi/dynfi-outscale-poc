#!/bin/sh

# Create a VM
echo "Getting security group ready..."
COMPILE_SECGROUP_ID=$(aws ec2 describe-security-groups --profile $PROFILE --endpoint $VM_ENDPOINT --query "SecurityGroups[?GroupName=='$COMPILE_SECGROUP_NAME'].GroupId" --output text)
if [ -z "$COMPILE_SECGROUP_ID" ]; then
    echo "Security group not found. Creating security group..."
    COMPILE_SECGROUP_ID=$(aws ec2 create-security-group --profile $PROFILE --endpoint $VM_ENDPOINT --group-name $COMPILE_SECGROUP_NAME --description "Security group for AMI creation" --output text)
    aws ec2 authorize-security-group-ingress --profile $PROFILE --endpoint $VM_ENDPOINT --group-id $COMPILE_SECGROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0
    echo "Created and set up security group $COMPILE_SECGROUP_ID"
else
    echo "Security group already exists: $COMPILE_SECGROUP_ID"
fi
echo "Set up security group $COMPILE_SECGROUP_ID"

echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
	--profile $PROFILE \
	--endpoint $VM_ENDPOINT \
	--instance-type $INSTANCE_TYPE \
	--key-name $KEY_PAIR_NAME \
	--security-group-ids $COMPILE_SECGROUP_ID \
	--image-id $EC2_AMI \
	--query 'Instances[0].InstanceId' \
	--output text)

aws ec2 wait instance-running --profile $PROFILE --endpoint $VM_ENDPOINT --instance-ids $INSTANCE_ID
echo "Instance $INSTANCE_ID is running."

# Format, create mount point and mount (done in SSH)
IP=$(aws ec2 describe-instances --profile $PROFILE --endpoint $VM_ENDPOINT --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
echo "Machine IP : $IP"

# Loop until ssh-keyscan produces output
while true; do
  echo "Running ssh-keyscan for $IP ..."
  ssh-keyscan -H $IP > temp_known_hosts

  if [ -s temp_known_hosts ]; then
    echo "Host key obtained. Appending to known_hosts..."
    cat temp_known_hosts >> ~/.ssh/known_hosts
    rm temp_known_hosts
    break
  else
    echo "No host key found. Retrying..."
    sleep 1
    rm temp_known_hosts
  fi
done

# scp app into it
echo "Uploading the flask app"
ssh -i $KEY_PAIR_PATH $USER@$IP 'mkdir -p ~/flask_app'
scp -i $KEY_PAIR_PATH "flask_app/flask_app.py" $USER@$IP:/home/$USER/flask_app/app.py
scp -i $KEY_PAIR_PATH "flask_app/requirements.txt" $USER@$IP:/home/$USER/flask_app/requirements.txt

echo -e "${CYAN}"
echo ""
echo "Please connect to the server using the following line:"
echo ""
echo "ssh $USER@$IP"
echo ""
echo ""
echo "Then use these lines to set it up:"
echo ""
echo "sudo apt update"
echo "sudo apt upgrade"
echo "sudo reboot"
echo "sudo apt install python3.10-venv python3-pip"
echo "cd flask_app"
echo "python3 -m venv venv"
echo "source venv/bin/activate"
echo "pip install -r requirements.txt"
echo "run 'python3 app.py' to test the app"
echo "sudo cloud-init clean"
echo "sudo ufw allow 5000"
echo "rm ~/.bash_history"
echo "sudo shutdown now"
echo ""
echo ""
echo -e "${NC}"
read -p "$(echo -e ${RED}SSH INTO THE MACHINE AND RUN 'cloud-init clean' AS ROOT, then hit [Enter]${NC}) "

# Snapshot it
NEW_OMI_ID=$(aws ec2 create-image \
        --profile $PROFILE \
        --instance-id $INSTANCE_ID \
        --name $FLASK_OMI_NAME \
        --description "$FLASK_OMI_DESCRIPTION" \
        --no-reboot \
        --endpoint $VM_ENDPOINT \
        --query "ImageId" \
        --output text)

echo "Waiting for OMI $FLASK_OMI_ID to be ready ..."
aws ec2 wait image-available \
        --image-ids $NEW_OMI_ID \
        --endpoint $VM_ENDPOINT \
        --profile $PROFILE \


echo "OMI $FLASK_OMI_ID is ready! Cleaning up..."
aws ec2 terminate-instances --profile $PROFILE --endpoint $VM_ENDPOINT --instance-ids $INSTANCE_ID

