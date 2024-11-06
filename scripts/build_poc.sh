#!/bin/sh

# https://docs.outscale.com/fr/userguide/%C3%80-propos-des-Nets.html

# Retrieve or set keypair

# Check if the key pair already exists
if aws ec2 describe-key-pairs --profile $PROFILE --endpoint $VM_ENDPOINT --key-names "$KEY_PAIR_NAME" --query "KeyPairs[*].KeyName" --output text 2>/dev/null | grep -q "$KEY_PAIR_NAME"; then
    echo "Key pair $KEY_PAIR_NAME already exists. Ignoring import."
else
    # Import the key pair if it does not exist
    aws ec2 import-key-pair \
 	--profile $PROFILE \
 	--endpoint $VM_ENDPOINT \
 	--key-name $KEY_PAIR_NAME \
 	--public-key-material fileb://$KEY_PAIR_PATH.pub
    echo "Key pair $KEY_PAIR_NAME imported successfully."
fi


# Fetch latest DFF OMI
FLASK_OMI_ID=$(aws ec2 describe-images \
	--owners self \
	--profile $PROFILE \
	--endpoint $VM_ENDPOINT \
	--query "Images[?Description=='$FLASK_OMI_DESCRIPTION'] | sort_by(@, &Name) | [-1].ImageId" \
	--output text
)
DFF_OMI_ID=$(aws ec2 describe-images \
	--owners self \
	--profile $PROFILE \
	--endpoint $VM_ENDPOINT \
	--query "Images[?Description=='$DFF_OMI_DESCRIPTION'] | sort_by(@, &Name) | [-1].ImageId" \
	--output text
)
DFM_OMI_ID=$(aws ec2 describe-images \
	--owners self \
	--profile $PROFILE \
	--endpoint $VM_ENDPOINT \
	--query "Images[?Description=='$DFM_OMI_DESCRIPTION'] | sort_by(@, &Name) | [-1].ImageId" \
	--output text
)
echo "Using OMI $DFF_OMI_ID for DFF, $DFM_OMI_ID for DFM and $FLASK_OMI_ID for Flask"

# Create a net with LAN and WAN
NET_ID=$(aws ec2 create-vpc \
	--profile $PROFILE \
	--cidr-block 10.0.0.0/16 \
	--instance-tenancy default \
	--endpoint $VM_ENDPOINT \
	--query "Vpc.VpcId" \
	--output text)
echo "NET_ID=$NET_ID"

# Create WAN subnet
WAN_SUBNET_ID=$(aws ec2 create-subnet \
	--profile $PROFILE \
	--vpc-id $NET_ID \
	--cidr-block 10.0.1.0/24 \
	--availability-zone $SUBREGION \
	--endpoint $VM_ENDPOINT \
	--query "Subnet.SubnetId" \
	--output text)
echo "WAN_SUBNET_ID=$WAN_SUBNET_ID"

# Create LAN subnet
LAN_SUBNET_ID=$(aws ec2 create-subnet \
	--profile $PROFILE \
	--vpc-id $NET_ID \
	--cidr-block 10.0.2.0/24 \
	--availability-zone $SUBREGION \
	--endpoint $VM_ENDPOINT \
	--query "Subnet.SubnetId" \
	--output text)
echo "LAN_SUBNET_ID=$LAN_SUBNET_ID"

# Create poc security group
POC_SECGROUP_ID=$(aws ec2 create-security-group \
	--group-name "$POC_SECGROUP_NAME" \
	--description "$POC_SECGROUP_DESCRIPTION" \
	--vpc-id "$NET_ID" \
	--profile "$PROFILE" \
	--endpoint "$VM_ENDPOINT" \
	--query "GroupId" \
	--output text)

# Allow everything in
aws ec2 authorize-security-group-ingress \
    --profile $PROFILE \
    --endpoint $VM_ENDPOINT \
    --group-id $POC_SECGROUP_ID \
    --protocol -1 \
    --port -1 \
    --cidr 0.0.0.0/0

echo "POC_SECGROUP_ID=$POC_SECGROUP_ID"


# Create poc public security group
#POC_PUBLIC_SECGROUP_ID=$(aws ec2 create-security-group \
#        --group-name "$POC_PUBLIC_SECGROUP_NAME" \
#        --description "$POC_PUBLIC_SECGROUP_DESCRIPTION" \
#        --profile "$PROFILE" \
#        --endpoint "$VM_ENDPOINT" \
#        --query "GroupId" \
#        --output text)
#
## Allowing 22, 80, and 443 in
#aws ec2 authorize-security-group-ingress \
#    --profile "$PROFILE" \
#    --endpoint "$VM_ENDPOINT" \
#    --group-id "$POC_PUBLIC_SECGROUP_ID" \
#    --protocol "tcp" \
#    --port "22" \
#    --cidr "${MY_LOCAL_IP}/32"
#
#aws ec2 authorize-security-group-ingress \
#    --profile "$PROFILE" \
#    --endpoint "$VM_ENDPOINT" \
#    --group-id "$POC_PUBLIC_SECGROUP_ID" \
#    --protocol "tcp" \
#    --port "80" \
#    --cidr "${MY_LOCAL_IP}/32"
#
#aws ec2 authorize-security-group-ingress \
#    --profile "$PROFILE" \
#    --endpoint "$VM_ENDPOINT" \
#    --group-id "$POC_PUBLIC_SECGROUP_ID" \
#    --protocol "tcp" \
#    --port "443" \
#    --cidr "${MY_LOCAL_IP}/32"
#
#echo "POC_PUBLIC_SECGROUP_ID=$POC_PUBLIC_SECGROUP_ID"


# Start DFM VM
## Start DFM on public cloud
#INSTANCE_ID_DFM=$(aws ec2 run-instances \
#        --profile $PROFILE \
#        --endpoint $VM_ENDPOINT \
#        --instance-type $INSTANCE_TYPE \
#        --key-name $KEY_PAIR_NAME \
#        --security-group-ids $POC_PUBLIC_SECGROUP_ID \
#        --image-id $DFM_OMI_ID \
#        --query 'Instances[0].InstanceId' \
#	--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=DFM-instance},{Key=Environment,Value=Dev}]' \
#        --output text)
#echo "INSTANCE_ID_DFM=$INSTANCE_ID_DFM"
## Start DFM on WAN
INSTANCE_ID_DFM=$(aws ec2 run-instances \
        --profile $PROFILE \
        --endpoint $VM_ENDPOINT \
        --instance-type $INSTANCE_TYPE \
        --private-ip-address 10.0.1.11 \
        --key-name $KEY_PAIR_NAME \
        --security-group-ids $POC_SECGROUP_ID \
        --image-id $DFM_OMI_ID \
        --subnet-id $WAN_SUBNET_ID \
        --query 'Instances[0].InstanceId' \
	--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=DFM-instance},{Key=Environment,Value=Dev}]' \
        --output text)
echo "INSTANCE_ID_DFM=$INSTANCE_ID_DFM"


# Start DFF VM
INSTANCE_ID_DFF=$(aws ec2 run-instances \
        --profile $PROFILE \
        --endpoint $VM_ENDPOINT \
        --instance-type $INSTANCE_TYPE \
        --private-ip-address 10.0.1.10 \
        --key-name $KEY_PAIR_NAME \
        --security-group-ids $POC_SECGROUP_ID \
        --image-id $DFF_OMI_ID \
        --subnet-id $WAN_SUBNET_ID \
        --user-data $CLOUDINIT_DFF_CONFIG \
        --query 'Instances[0].InstanceId' \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=DFF-instance},{Key=Environment,Value=Dev}]' \
        --output text)
echo "INSTANCE_ID_DFF=$INSTANCE_ID_DFF"

# Get already existing interface
NIC_ID_WAN=$(aws ec2 describe-instances \
        --profile $PROFILE \
        --endpoint $VM_ENDPOINT \
        --instance-ids "$INSTANCE_ID_DFF" \
        --query 'Reservations[*].Instances[*].NetworkInterfaces[*].{NetworkInterfaceId:NetworkInterfaceId,PrivateIpAddress:PrivateIpAddress}[0].NetworkInterfaceId' \
        --output text)
echo "NIC_ID_WAN=$NIC_ID_WAN"

# Assign new interface to DFF VM
NIC_ID_LAN=$(aws ec2 create-network-interface \
	--profile $PROFILE \
	--subnet-id $LAN_SUBNET_ID \
	--private-ip-address 10.0.2.10 \
	--description $NIC_DESCRIPTION \
	--endpoint $VM_ENDPOINT \
	--group $POC_SECGROUP_ID \
	--query "NetworkInterface.NetworkInterfaceId" \
	--output text)
echo "NIC_ID_LAN=$NIC_ID_LAN"

echo "Waiting from dff instance to start running"
aws ec2 wait instance-running --profile $PROFILE --endpoint $VM_ENDPOINT --instance-ids $INSTANCE_ID_DFF 
echo "Instance $INSTANCE_ID_DFF is running."


aws ec2 attach-network-interface \
	--profile $PROFILE \
	--network-interface-id $NIC_ID_LAN \
	--instance-id $INSTANCE_ID_DFF \
	--device-index 1 \
	--endpoint $VM_ENDPOINT

echo "Opening the NIC"
aws ec2 modify-instance-attribute \
	--profile $PROFILE \
	--endpoint $VM_ENDPOINT \
	--instance-id $INSTANCE_ID_DFF \
	--source-dest-check "{\"Value\": false}"

# Assign public IP to DFF and DFM VMs public interface
OUTPUT=$(aws ec2 allocate-address \
    --profile "$PROFILE" \
    --domain vpc \
    --endpoint "$VM_ENDPOINT")
PUBLIC_IP_DFF=$(echo "$OUTPUT" | jq -r '.PublicIp')
PUBLIC_IP_DFF_ALLOCATION_ID=$(echo "$OUTPUT" | jq -r '.AllocationId')
echo "PUBLIC_IP_DFF=$PUBLIC_IP_DFF"
echo "PUBLIC_IP_DFF_ALLOCATION_ID=$PUBLIC_IP_DFF_ALLOCATION_ID"

OUTPUT=$(aws ec2 allocate-address \
    --profile "$PROFILE" \
    --domain vpc \
    --endpoint "$VM_ENDPOINT")
PUBLIC_IP_DFM=$(echo "$OUTPUT" | jq -r '.PublicIp')
PUBLIC_IP_DFM_ALLOCATION_ID=$(echo "$OUTPUT" | jq -r '.AllocationId')
echo "PUBLIC_IP_DFM=$PUBLIC_IP_DFM"
echo "PUBLIC_IP_DFM_ALLOCATION_ID=$PUBLIC_IP_DFM_ALLOCATION_ID"

INTERNET_GATEWAY_ID=$(aws ec2 create-internet-gateway \
    --profile $PROFILE \
    --endpoint $VM_ENDPOINT \
    --query "InternetGateway.InternetGatewayId" \
    --output text)
echo "INTERNET_GATEWAY_ID=$INTERNET_GATEWAY_ID"

aws ec2 attach-internet-gateway \
	--profile $PROFILE \
	--internet-gateway-id $INTERNET_GATEWAY_ID \
	--vpc-id $NET_ID \
	--endpoint $VM_ENDPOINT

NET_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
	--profile "$PROFILE" \
	--endpoint "$VM_ENDPOINT" \
	--query "RouteTables[?VpcId=='$NET_ID'].RouteTableId" \
	--output text)
echo "NET_ROUTE_TABLE_ID=$NET_ROUTE_TABLE_ID"

aws ec2 create-route \
	--profile $PROFILE \
	--route-table-id $NET_ROUTE_TABLE_ID \
	--destination-cidr-block 0.0.0.0/0 \
	--gateway-id $INTERNET_GATEWAY_ID \
	--endpoint $VM_ENDPOINT

echo "WAN : Affectation de la route au réseau"
aws ec2 associate-route-table \
        --profile $PROFILE \
        --subnet-id $WAN_SUBNET_ID \
        --route-table-id $NET_ROUTE_TABLE_ID \
        --endpoint $VM_ENDPOINT

echo "WAN : Affectation de l'IP public de DFF"
aws ec2 associate-address \
	--profile $PROFILE \
	--allocation-id $PUBLIC_IP_DFF_ALLOCATION_ID \
	--instance-id $INSTANCE_ID_DFF \
	--network-interface-id $NIC_ID_WAN \
	--endpoint $VM_ENDPOINT

echo "WAN : Affectation de l'IP public de DFM"
aws ec2 associate-address \
	--profile $PROFILE \
	--allocation-id $PUBLIC_IP_DFM_ALLOCATION_ID \
	--instance-id $INSTANCE_ID_DFM \
	--endpoint $VM_ENDPOINT


echo "LAN : Creation de la table de route"
LAN_ROUTE_TABLE_ID=$(aws ec2 create-route-table \
	--profile $PROFILE \
	--vpc-id $NET_ID \
	--endpoint $VM_ENDPOINT \
	--query "RouteTable.RouteTableId" \
	--output text)
echo "LAN_ROUTE_TABLE_ID=$LAN_ROUTE_TABLE_ID"

echo "LAN : Creation de la route"
aws ec2 create-route \
	--profile $PROFILE \
	--route-table-id $LAN_ROUTE_TABLE_ID \
	--destination-cidr-block 0.0.0.0/0 \
	--gateway-id $NIC_ID_LAN \
	--endpoint $VM_ENDPOINT

echo "LAN : Affectation de la route au réseau"
aws ec2 associate-route-table \
	--profile $PROFILE \
	--subnet-id $LAN_SUBNET_ID \
	--route-table-id $LAN_ROUTE_TABLE_ID \
	--endpoint $VM_ENDPOINT



# Verify the route with a loop
echo "Waiting for route propagation..."

ROUTE_STATE=""

while [ "$ROUTE_STATE" != "active" ] ; do
    ROUTE_STATE=$(aws ec2 describe-route-tables \
        --profile $PROFILE \
        --endpoint $VM_ENDPOINT \
        --route-table-ids $LAN_ROUTE_TABLE_ID \
        --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].State" \
        --output text)
    if [ "$ROUTE_STATE" != "active" ]; then
        echo "Route is not active yet. Retrying ..."
        sleep 1
    fi
done

echo "Route is active. Proceeding."


# Launch Flask apps in the subnet
INSTANCE_ID_FLASK_A=$(aws ec2 run-instances \
        --profile $PROFILE \
        --endpoint $VM_ENDPOINT \
	--private-ip-address 10.0.2.11 \
        --instance-type $INSTANCE_TYPE \
        --key-name $KEY_PAIR_NAME \
        --security-group-ids $POC_SECGROUP_ID \
        --image-id $FLASK_OMI_ID \
	--user-data $CLOUDINIT_FLASK_CONFIG_A \
	--subnet-id $LAN_SUBNET_ID \
        --query 'Instances[0].InstanceId' \
        --output text)
echo "INSTANCE_ID_FLASK_A=$INSTANCE_ID_FLASK_A"
PRIVATE_IP_FLASK_A=$(aws ec2 describe-instances --profile $PROFILE --endpoint $VM_ENDPOINT --instance-ids $INSTANCE_ID_FLASK_A --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)

INSTANCE_ID_FLASK_B=$(aws ec2 run-instances \
        --profile $PROFILE \
        --endpoint $VM_ENDPOINT \
	--private-ip-address 10.0.2.12 \
        --instance-type $INSTANCE_TYPE \
        --key-name $KEY_PAIR_NAME \
        --security-group-ids $POC_SECGROUP_ID \
        --image-id $FLASK_OMI_ID \
	--user-data $CLOUDINIT_FLASK_CONFIG_B \
	--subnet-id $LAN_SUBNET_ID \
        --query 'Instances[0].InstanceId' \
        --output text)
echo "INSTANCE_ID_FLASK_B=$INSTANCE_ID_FLASK_B"
PRIVATE_IP_FLASK_B=$(aws ec2 describe-instances --profile $PROFILE --endpoint $VM_ENDPOINT --instance-ids $INSTANCE_ID_FLASK_B --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)


# Waiting for the DFF instance to finish its set up
echo -n "Waiting for DFF to finish booting..."
while true; do
    curl -s -k -m 5 https://$PUBLIC_IP_DFF > /dev/null
    CURL_EXIT_CODE=$?
    if [[ $CURL_EXIT_CODE -ne 28 ]]; then
        echo ""
        echo "DFF finished booting!"
        break
    else
        echo -n "."
        sleep 1
    fi
done


echo -e "${CYAN}"
echo ""
echo ""
echo ""
echo "DFF Instance $INSTANCE_ID_DFF is running. Connect on https://$PUBLIC_IP_DFF"
echo "DFM Instance $INSTANCE_ID_DFM is running. Connect on https://$PUBLIC_IP_DFM"
echo ""
echo ""
echo "Assign vtnet1 to LAN, then save, then enable the LAN interface"
echo "https://$PUBLIC_IP_DFF/interfaces_assign.php"
echo ""
echo "Open the LAN to everything"
echo "http://$PUBLIC_IP_DFF/firewall_rules.php?if=opt1"
echo ""
echo "ssh root@$PUBLIC_IP_DFF"
echo "curl -X GET http://$PRIVATE_IP_FLASK_A:5000/get-name"
echo "curl -X GET http://$PRIVATE_IP_FLASK_B:5000/get-name"
echo ""
echo "Enable routing"
echo "http://$PUBLIC_IP_DFF/ui/quagga/general/index"
echo ""
echo "ssh root@$PUBLIC_IP_DFF"
echo "curl -X GET http://$PRIVATE_IP_FLASK_A:5000/test-connectivity"
echo ""
echo "Set up HAProxy"
echo "http://$PUBLIC_IP_DFF/ui/haproxy#general-settings"
echo ""
echo "Open 8081 and 8082"
echo "http://$PUBLIC_IP_DFF/firewall_rules.php?if=wan"
echo ""
echo "http://$PUBLIC_IP_DFF:8081/get-name"
echo "http://$PUBLIC_IP_DFF:8082/get-name"
echo "http://$PUBLIC_IP_DFF:8081/test-connectivity"
echo ""
echo ""
echo ""
echo -e "${NC}"

read -p "$(echo -e ${GREEN}Hit [Enter] when the you want to clear the poc${NC}) "

# Cleaning
aws ec2 terminate-instances --instance-ids $INSTANCE_ID_DFF --profile $PROFILE --endpoint $VM_ENDPOINT
aws ec2 terminate-instances --instance-ids $INSTANCE_ID_DFM --profile $PROFILE --endpoint $VM_ENDPOINT

aws ec2 terminate-instances --instance-ids $INSTANCE_ID_FLASK_A --profile $PROFILE --endpoint $VM_ENDPOINT
aws ec2 terminate-instances --instance-ids $INSTANCE_ID_FLASK_B --profile $PROFILE --endpoint $VM_ENDPOINT

aws ec2 wait instance-terminated --profile $PROFILE --endpoint $VM_ENDPOINT --instance-ids $INSTANCE_ID_DFF
aws ec2 wait instance-terminated --profile $PROFILE --endpoint $VM_ENDPOINT --instance-ids $INSTANCE_ID_DFM
aws ec2 wait instance-terminated --profile $PROFILE --endpoint $VM_ENDPOINT --instance-ids $INSTANCE_ID_FLASK_A
aws ec2 wait instance-terminated --profile $PROFILE --endpoint $VM_ENDPOINT --instance-ids $INSTANCE_ID_FLASK_B

# Release Elastic IP
echo "Releasing public IP"
aws ec2 release-address --profile $PROFILE --endpoint $VM_ENDPOINT --allocation-id $PUBLIC_IP_DFF_ALLOCATION_ID
aws ec2 release-address --profile $PROFILE --endpoint $VM_ENDPOINT --allocation-id $PUBLIC_IP_DFM_ALLOCATION_ID

# Delete Network Interface
echo "Deleting NIC"
aws ec2 delete-network-interface --profile $PROFILE --endpoint $VM_ENDPOINT --network-interface-id $NIC_ID_LAN

# Deleting internet gateway
echo "Deleting internet gateway"
aws ec2 detach-internet-gateway --profile $PROFILE --endpoint $VM_ENDPOINT --internet-gateway-id $INTERNET_GATEWAY_ID --vpc-id $NET_ID
aws ec2 delete-internet-gateway --profile $PROFILE --endpoint $VM_ENDPOINT --internet-gateway-id $INTERNET_GATEWAY_ID

# Delete Security Group
echo "Deleting security group"
aws ec2 delete-security-group --profile $PROFILE --endpoint $VM_ENDPOINT --group-id $POC_SECGROUP_ID
#aws ec2 delete-security-group --profile $PROFILE --endpoint $VM_ENDPOINT --group-id $POC_PUBLIC_SECGROUP_ID

# Delete Subnet
echo "Deleting subnets"
aws ec2 delete-subnet --profile $PROFILE --endpoint $VM_ENDPOINT --subnet-id $WAN_SUBNET_ID
aws ec2 delete-subnet --profile $PROFILE --endpoint $VM_ENDPOINT --subnet-id $LAN_SUBNET_ID

# Delete Route Table
echo "Deleting route table"
aws ec2 delete-route-table --profile $PROFILE --endpoint $VM_ENDPOINT --route-table-id $LAN_ROUTE_TABLE_ID

# Delete VPC
echo "Deleting Net"
aws ec2 delete-vpc --profile $PROFILE --endpoint $VM_ENDPOINT --vpc-id $NET_ID
