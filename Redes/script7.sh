#!/bin/bash

echo "=== Creando VPC ==="

VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 172.16.0.0/16 \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=VPCAGM2}]" \
    --query Vpc.VpcId --output text)

echo "VPC creada: $VPC_ID"


echo "=== Creando Subred Pública ==="

SUB_ID=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block 172.16.0.0/24 \
    --availability-zone us-east-1a \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=SBPublica2}]" \
    --query Subnet.SubnetId --output text)

echo "Subred Pública: $SUB_ID"


echo "=== Creando Subred Privada ==="

SUB_ID2=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block 172.16.128.0/24 \
    --availability-zone us-east-1a \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=SBPrivate2}]" \
    --query Subnet.SubnetId --output text)

echo "Subred Privada: $SUB_ID2"


echo "=== Activando IP pública automática en subred pública ==="

aws ec2 modify-subnet-attribute \
    --subnet-id "$SUB_ID" \
    --map-public-ip-on-launch


echo "=== Creando Security Group ==="

SG_ID=$(aws ec2 create-security-group \
    --group-name sgmio2 \
    --description "SG para SSH e ICMP" \
    --vpc-id "$VPC_ID" \
    --query GroupId --output text)

echo "SG creado: $SG_ID"


echo "=== Añadiendo reglas SSH + ICMP ==="

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --ip-permissions "[
    {
      \"IpProtocol\": \"tcp\",
      \"FromPort\": 22,
      \"ToPort\": 22,
      \"IpRanges\": [
        {
          \"CidrIp\": \"0.0.0.0/0\",
          \"Description\": \"SSH from anywhere\"
        }
      ]
    },
    {
      \"IpProtocol\": \"icmp\",
      \"FromPort\": -1,
      \"ToPort\": -1,
      \"IpRanges\": [
        {
          \"CidrIp\": \"0.0.0.0/0\",
          \"Description\": \"All ICMP\"
        }
      ]
    }
  ]"


echo "=== Creando Internet Gateway ==="

IGW_ID=$(aws ec2 create-internet-gateway \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=my-igwalex3}]" \
    --query InternetGateway.InternetGatewayId --output text)

echo "IGW creado: $IGW_ID"

aws ec2 attach-internet-gateway \
    --internet-gateway-id "$IGW_ID" \
    --vpc-id "$VPC_ID"


echo "=== Creando Route Table Pública ==="

RT_ID=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --query RouteTable.RouteTableId --output text)

echo "Route Table: $RT_ID"

aws ec2 create-route \
    --route-table-id "$RT_ID" \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id "$IGW_ID"

aws ec2 associate-route-table \
    --route-table-id "$RT_ID" \
    --subnet-id "$SUB_ID"



EIP_ALLOC_ID=$(aws ec2 allocate-address --query AllocationId --output text)

NGW_ID=$(aws ec2 create-nat-gateway \
    --subnet-id "$SUB_ID" \
    --allocation-id "$EIP_ALLOC_ID" \
    --query NatGateway.NatGatewayId \
    --output text)

echo "NAT Gateway creado: $NGW_ID"
aws ec2 wait nat-gateway-available --nat-gateway-ids "$NGW_ID"


echo "=== Creando Route Table Privada ==="

RT_PRIV_ID=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --query RouteTable.RouteTableId \
    --output text)

echo "Route Table Privada: $RT_PRIV_ID"


# Crear la ruta por el NAT Gateway
aws ec2 create-route \
    --route-table-id "$RT_PRIV_ID" \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id "$NGW_ID"

# Asociar la RT privada a la subred privada
aws ec2 associate-route-table \
    --route-table-id "$RT_PRIV_ID" \
    --subnet-id "$SUB_ID2"


echo "=== Lanzando EC2 Pública ==="

EC2_ID1=$(aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --instance-type t3.micro \
    --subnet-id "$SUB_ID" \
    --key-name vockey \
    --security-group-ids "$SG_ID" \
    --associate-public-ip-address \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Ec2Publica3}]" \
    --query "Instances[0].InstanceId" --output text)

echo "EC2 Pública creada: $EC2_ID1"


echo "=== Lanzando EC2 Privada ==="

EC2_ID2=$(aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --instance-type t3.micro \
    --subnet-id "$SUB_ID2" \
    --key-name vockey \
    --security-group-ids "$SG_ID" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=Ec2Privada3}]" \
    --query "Instances[0].InstanceId" --output text)

echo "EC2 Privada creada: $EC2_ID2"

