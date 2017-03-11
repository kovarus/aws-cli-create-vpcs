#!/bin/bash
#
#******************************************************************************
#    AWS VPC Creation Shell Script
#******************************************************************************
#
# SYNOPSIS
#    Automates the creation of a custom IPv4 VPC, having both a public and a
#    private subnet, and a NAT gateway.
#
# DESCRIPTION
#    This shell script leverages the AWS Command Line Interface (awscli) to
#    automatically create a custom VPC.  The script assumes the awscli is
#    installed and configured with the necessary security credentials.  This
#    script also depends on a lightweight JSON parser, jq
#
#==============================================================================
#
# NOTES
#    VERSION:   0.1
#    LASTEDIT:  02/25/2017
#    AUTHOR:    Joe Arauzo
#    EMAIL:     joe@arauzo.net
#    REVISIONS:
#        0.1  02/25/2017 - initial script
#
#==============================================================================
#   MODIFY THE SETTINGS BELOW
#==============================================================================
#
AWS_REGION="us-west-1"
VPC_NAME="My VPC"
VPC_CIDR="10.0.0.0/16"
SUBNET_PUBLIC_CIDR="10.0.1.0/24"
SUBNET_PUBLIC_AZ="us-west-1a"
SUBNET_PUBLIC_NAME="10.0.1.0 - us-west-1a"
SUBNET_PRIVATE_CIDR="10.0.2.0/24"
SUBNET_PRIVATE_AZ="us-west-1c"
SUBNET_PRIVATE_NAME="10.0.2.0 - us-west-1b"
#
#==============================================================================
#   DO NOT MODIFY CODE BELOW
#==============================================================================
#
# Create VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region $AWS_REGION \
  | jq -r '.Vpc.VpcId')
echo "VPC with ID '$VPC_ID' was created in '$AWS_REGION' region."

# Add Name tag to VPC
aws ec2 create-tags --resources $VPC_ID --tags "Key=Name,Value=$VPC_NAME" \
  --region $AWS_REGION
echo "VPC with ID '$VPC_ID' has been named '$VPC_NAME'."

# Create Public Subnet
SUBNET_PUBLIC_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block $SUBNET_PUBLIC_CIDR --availability-zone $SUBNET_PUBLIC_AZ \
  --region $AWS_REGION | jq -r '.Subnet.SubnetId')
echo "Subnet with ID '$SUBNET_PUBLIC_ID' was created in '$SUBNET_PUBLIC_AZ'" \
  "Availability Zone."

# Add Name tag to Public Subnet
aws ec2 create-tags --resources $SUBNET_PUBLIC_ID \
  --tags "Key=Name,Value=$SUBNET_PUBLIC_NAME" --region $AWS_REGION
echo "Subnet with ID '$SUBNET_PUBLIC_ID' has been named '$SUBNET_PUBLIC_NAME'."

# Create Private Subnet
SUBNET_PRIVATE_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID \
  --cidr-block $SUBNET_PRIVATE_CIDR --availability-zone $SUBNET_PRIVATE_AZ \
  --region $AWS_REGION | jq -r '.Subnet.SubnetId')
echo "Subnet with ID '$SUBNET_PRIVATE_ID' was created in '$SUBNET_PRIVATE_AZ'" \
  "Availability Zone."

# Add Name tag to Private Subnet
aws ec2 create-tags --resources $SUBNET_PRIVATE_ID \
  --tags "Key=Name,Value=$SUBNET_PRIVATE_NAME" --region $AWS_REGION
echo "Subnet with ID '$SUBNET_PRIVATE_ID' has been named" \
  "'$SUBNET_PRIVATE_NAME'."

# Create Internet gateway
IGW_ID=$(aws ec2 create-internet-gateway --region $AWS_REGION \
  | jq -r '.InternetGateway.InternetGatewayId')
echo "Internet Gateway with ID '$IGW_ID' was created."

# Attach Internet gateway to your VPC
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
echo "Internet Gateway ID '$IGW_ID' was was attached to VPC ID '$VPC_ID'."

# Create Route Table
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID \
  --region $AWS_REGION | jq -r '.RouteTable.RouteTableId')
echo "Route Table with ID '$ROUTE_TABLE_ID' was created."

# Create route to Internet Gateway
RESULT=$(aws ec2 create-route --route-table-id $ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $AWS_REGION)
echo "Added route to '0.0.0.0/0' via Internet Gateway ID '$IGW_ID' to" \
  "Route Table ID '$ROUTE_TABLE_ID'."

# Associate Public Subnet with Route Table
RESULT=$(aws ec2 associate-route-table  --subnet-id $SUBNET_PUBLIC_ID \
  --route-table-id $ROUTE_TABLE_ID --region $AWS_REGION)
echo "Associated Public Subnet ID '$SUBNET_PUBLIC_ID' with Route Table ID" \
  "'$ROUTE_TABLE_ID'."

# Enable Auto-assign Public IP on Public Subnet
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_PUBLIC_ID \
  --map-public-ip-on-launch --region $AWS_REGION
echo "Enabled 'Auto-assign Public IP' on Public Subnet ID '$SUBNET_PUBLIC_ID'."

# Allocate Elastic IP Address for NAT Gateway
EIP_ALLOC_ID=$(aws ec2 allocate-address --domain vpc --region $AWS_REGION \
  | jq -r '.AllocationId')
echo "Allocated Elastic IP address ID '$EIP_ALLOC_ID'."

# Create NAT Gateway
NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $SUBNET_PUBLIC_ID \
  --allocation-id $EIP_ALLOC_ID \
  --query 'NatGateway.{NatGatewayId:NatGatewayId}' \
  --output text \
  --region $AWS_REGION)
SECONDS=0
echo "Creating NAT Gateway having ID '$NAT_GW_ID' and waiting..."
FORMATTED_MSG="STATUS: %s  %02dh:%02dm:%02ds elapsed while waiting for NAT "
FORMATTED_MSG+="Gateway to become available."
STATE=''
until [[ $STATE == 'available' ]]; do
  SECS=$SECONDS
  ELAPSED=$(printf "$FORMATTED_MSG" \
    $STATE $(($SECS/3600)) $(($SECS%3600/60)) $(($SECS%60)))
  printf " $ELAPSED\033[0K\r"
  STATE=$(aws ec2 describe-nat-gateways \
    --nat-gateway-ids $NAT_GW_ID \
    --query 'NatGateways[*].{State:State}' \
    --output text \
    --region $AWS_REGION)
  sleep 1
done
printf "\nNAT Gateway with ID '$NAT_GW_ID' is now AVAILABLE."

# Create route to NAT Gateway
MAIN_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --filters Name=vpc-id,Values=$VPC_ID Name=association.main,Values=true \
  --query 'RouteTables[*].{RouteTableId:RouteTableId}' \
  --output text \
  --region $AWS_REGION)
echo "Main Route Table ID is '$MAIN_ROUTE_TABLE_ID'."
RESULT=$(aws ec2 create-route \
  --route-table-id $MAIN_ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $NAT_GW_ID \
  --region $AWS_REGION)
echo "Added route to '0.0.0.0/0' via NAT Gateway with ID '$NAT_GW_ID' to" \
  "Route Table ID '$MAIN_ROUTE_TABLE_ID'."
