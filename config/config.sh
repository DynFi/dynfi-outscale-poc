# Outscale config
export PROFILE="DYNFI_POC_PROFILE"
export REGION="eu-west-2"
export SUBREGION="eu-west-2a"

# Misc
export DATE=$(date +%Y-%m-%d-%H-%M-%S)
export MY_LOCAL_IP=$(curl https://ipinfo.io/ip)

# Main default
export DEFAULT_BUILD_FLASK_OMI="N"
export DEFAULT_UPDATE_FLASK_OMI="N"
export DEFAULT_BUILD_POC="Y"

# DFF VM
export DFF_OMI_DESCRIPTION="DynFi Firewall cloud image"
export DFM_OMI_DESCRIPTION="DynFi Manager cloud image"

# SSH
export KEY_PAIR_PATH="~/.ssh/poc"
export KEY_PAIR_NAME="poc_keypair"

# Names
#export TEST_SECGROUP_NAME="test_flask_secgroup"
#export DEPLOY_SECGROUP_NAME="dff_production_secgroup"

export INSTANCE_TYPE="tinav4.c2r4p2"
export EC2_AMI="ami-044c54f9"
export USER="outscale"

export VM_ENDPOINT="https://fcu.$REGION.outscale.com"

# Update VM online
export UPDATE_SECGROUP_NAME="update-secgroup-name"
export UPDATE_SECGROUP_DESCRIPTION="secgroup used to update DFF VM"

 
# Build POC
export CLOUDINIT_DFF_CONFIG="file://cloud-init/cloud-config-DFF.yaml"
export CLOUDINIT_FLASK_CONFIG_A="file://cloud-init/cloud-config-Flask-A.yaml"
export CLOUDINIT_FLASK_CONFIG_B="file://cloud-init/cloud-config-Flask-B.yaml"
export POC_SECGROUP_NAME="poc-secgroup"
export POC_SECGROUP_DESCRIPTION="secgroup-for-poc-demonstration"
export NIC_DESCRIPTION="DFF-network-interface-card"
export FLASK_OMI_NAME="DFF-Flask-POC-$DATE"
export FLASK_OMI_DESCRIPTION="DynFi Firewall Flask dummy app used for POC"
export POC_PUBLIC_SECGROUP_NAME="poc-public-secgroup"
export POC_PUBLIC_SECGROUP_DESCRIPTION="poc-public-secgroup"
