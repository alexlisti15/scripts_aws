
    #Creo la vpc y devuelvo su id
    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block 192.168.0.0/24 \
        --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=VPCALEX2}]' \
        --query Vpc.VpcId --output text) 

    #Muestro el id de la vpc
    echo $VPC_ID
    #habilitar dns en la vpc
    aws ec2 modify-vpc-attribute \
        --vpc-id $VPC_ID \
        --enable-dns-hostnames "{\"Value\":true}"

    SUB_ID=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block 192.168.0.1/28 \
        --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Subred2-Alex}]' \
        --query Subnet.SubnetId --output text)

        echo $SUB_ID 

    #Habilitar la asignacion de ipv4publica en la subred 
    #Comprobar como no se hailita y tendremos que hacerlo a posteriori
    aws ec2 modify-subnet-attribute --subnet-id $SUB_ID --map-public-ip-on-launch

    #Crear grupo Security Group 
    SG_ID=$(aws ec2 create-security-group \
    --group-name sgmio2 \
    --description "Mi grupo de seguridad para abrir el puerto 22" \
    --vpc-id $VPC_ID \
    --query GroupId --output text )

    echo "Security Group ID: $SG_ID"

# Autorizar el tráfico SSH (puerto 22) desde cualquier IP
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --ip-permissions '[{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "All"}]}]'

# Crear una instancia EC2 en la subred especificada
EC2_ID=$(aws ec2 run-instances \
  --image-id ami-0360c520857e3138f \
  --instance-type t3.micro \
  --subnet-id "$SUB_ID" \
  --security-group-ids $SG_ID \
  --key-name vockey \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC22}]' \
  --associate-public-ip-address \
  --query 'Instances[0].InstanceId' \
  --output text)



# Esperar unos segundos para que la instancia se inicialice
sleep 15

# Mostrar el ID de la instancia creada
echo "EC2 Instance ID: $EC2_ID"
        

    
