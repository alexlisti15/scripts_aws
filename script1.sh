
#Creo la vpc y devuelvo su id

VPC_ID=$(aws ec2 create-vpc \
    --cidr-block 192.168.0.0/24 \
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=VPCALEX}]' \
    --query Vpc.VpcId --output text) 