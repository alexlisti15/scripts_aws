
    #Creo la vpc y devuelvo su id
    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block 192.168.1.0/24 \
        --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=VPCALEX}]' \
        --query Vpc.VpcId --output text) 

    #Muestro el id de la vpc
    echo $VPC_ID
    #habilitar dns en la vpc
    aws ec2 modify-vpc-attribute \
        --vpc-id $VPC_ID \
        --enable-dns-hostnames "{\"Value\":true}"

    SUB_ID=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block 192.168.1.0/28 \
        --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=Subred1-Alex}]' \
        --query Subnet.SubnetId --output text)

        echo $SUB_ID 

    #Habilitar la asignacion de ipv4publica en la subred 
    #Comprobar como no se hailita y tendremos que hacerlo a posteriori
    aws ec2 modify-subnet-attribute --subnet-id $SUB_ID --map-public-ip-on-launch

    #Crear grupo Security Group 
    SG_ID=$(aws ec2 create-security-group \
    --group-name sgmio \
    --description "Mi grupo de seguridad para abrir el puerto 22" \
    --vpc-id $VPC_ID \
    --query GroupId --output text )

    echo $SG_ID

    #reglas grupo de seguridad
    aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 > /dev/null



    #Crear Ec2 y ponerlo en la subred 
    EC2_ID=$(aws ec2 run-instances \
    --image-id ami-0360c520857e3138f \
    --instance-type t3.micro \
    --subnet-id $SUB_ID \
    --key-name vockey \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC2}]' \
    --associate-public-ip-address \
    --query Instances.InstanceId --output text )



    sleep 15
    echo $EC2_ID

        

    
