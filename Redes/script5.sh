
    #Creo la vpc y devuelvo su id
    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block 192.168.0.0/24 \
        --tag-specifications 'ResourceType=vpc,Tags=[{Key=entorno,Value=prueba}]' \
        --query Vpc.VpcId --output text) 


    SUB_ID=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block 192.168.0.0/28 \
        --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=SubredAlex4}]' \
        --query Subnet.SubnetId --output text)

        echo $SUB_ID 

      SUB_ID2=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block 192.168.0.16/28 \
        --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=SubredAlex3}]' \
        --query Subnet.SubnetId --output text)

        echo $SUB_ID2 


        # Crear una instancia EC2 en la subred especificada
        EC2_ID=$(aws ec2 run-instances \
        --image-id ami-0360c520857e3138f \
        --instance-type t3.micro \
        --subnet-id "$SUB_ID" \
        --key-name vockey \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=MiEC8}]' \
        --associate-public-ip-address \
        --query 'Instances[0].InstanceId' \
        --output text)




    # Obtén los IDs de las VPCs que tienen la etiqueta entorno=prueba
     VPC_IDS=$(aws ec2 describe-vpcs \
    --filters "Name=tag:entorno,Values=prueba" \
    --query "Vpcs[*].VpcId" \
    --output text)

# Recorre cada ID de VPC y elimínala
for VPC_ID in $VPC_IDS; do
    echo "Eliminando VPC $VPC_ID..."
    
    # Eliminar recursos asociados (puentes de internet, subredes, etc.) antes de eliminar la VPC
    

    # Ejemplo: elimina subredes
    SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text)

    for SUBNET_ID in $SUBNET_IDS; do
    
    EC2_IDS=$(aws ec2 describe-instances \
    --filters "Name=subnet-id,Values=$SUBNET_ID" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text)
    
        for Ec2_ID in $Ec2_IDS; do 
        aws ec2 terminate-instances --instance-ids $Ec2_ID
        aws ec2 wait instance-terminated  --instance-ids $Ec2_ID
        done 

        aws ec2 delete-subnet --subnet-id $SUBNET_ID
        echo " Subnet $SUBNET_ID eliminada."
    done
    
    # (Opcional) Elimina más recursos aquí como Internet Gateways, Route Tables, etc., si existen
    
    # Elimina la VPC
    aws ec2 delete-vpc --vpc-id $VPC_ID
    echo "VPC $VPC_ID eliminada."
done
