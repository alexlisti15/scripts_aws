


#Creo la vpc y devuelvo su id
    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block 172.16.0.0/16 \
        --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=VPCALEX6}]' \
        --query Vpc.VpcId --output text) 

    #Muestro el id de la vpc
    echo $VPC_ID
    #habilitar dns en la vpc
    aws ec2 modify-vpc-attribute \
        --vpc-id $VPC_ID \
        --enable-dns-hostnames "{\"Value\":true}"

    SUB_ID=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block 172.16.0.0/20 \
        --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Subred6-Alex}]' \
        --query Subnet.SubnetId --output text)

        echo $SUB_ID 

    #Habilitar la asignacion de ipv4publica en la subred 
    #Comprobar como no se hailita y tendremos que hacerlo a posteriori
    aws ec2 modify-subnet-attribute --subnet-id $SUB_ID --map-public-ip-on-launch




      #Crear grupo Security Group 
    SG_ID=$(aws ec2 create-security-group \
    --group-name sgmio4 \
    --description "Mi grupo de seguridad para abrir el puerto 22" \
    --vpc-id $VPC_ID \
    --query GroupId --output text )

    echo "Security Group ID: $SG_ID"

# Autorizar el tráfico SSH (puerto 22) desde cualquier IP
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "All"}]}]'

    IGW_ID=$(aws ec2 create-internet-gateway \
        --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=my-igwalex4}]' \
        --query InternetGateway.InternetGatewayId --output text)

    aws ec2 attach-internet-gateway \
        --internet-gateway-id $IGW_ID \
        --vpc-id $VPC_ID

    RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query RouteTable.RouteTableId --output text)

    aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

    aws ec2 associate-route-table --route-table-id $RT_ID --subnet-id $SUB_ID 
    

    


