import boto3
import time

# -------------------------------
# FUNCIONES
# -------------------------------

def crear_vpc():
    ec2 = boto3.client('ec2')
    vpc = ec2.create_vpc(CidrBlock='172.16.0.0/16')
    vpc_id = vpc['Vpc']['VpcId']
    ec2.modify_vpc_attribute(VpcId=vpc_id, EnableDnsSupport={'Value': True})
    ec2.modify_vpc_attribute(VpcId=vpc_id, EnableDnsHostnames={'Value': True})
    ec2.create_tags(Resources=[vpc_id], Tags=[{'Key': 'Name', 'Value': 'VPCAGM3'}])
    return vpc_id

def crear_subred(vpc_id, cidr, az, nombre):
    ec2 = boto3.client('ec2')
    sub = ec2.create_subnet(VpcId=vpc_id, CidrBlock=cidr, AvailabilityZone=az)
    sub_id = sub['Subnet']['SubnetId']
    ec2.create_tags(Resources=[sub_id], Tags=[{'Key': 'Name', 'Value': nombre}])
    return sub_id

def ip_publica_subred(subnet_id):
    ec2 = boto3.client('ec2')
    ec2.modify_subnet_attribute(SubnetId=subnet_id, MapPublicIpOnLaunch={'Value': True})

def crear_security_group(vpc_id):
    ec2 = boto3.client('ec2')
    sg = ec2.create_security_group(GroupName='sgmio2', Description='SG para SSH e ICMP', VpcId=vpc_id)
    sg_id = sg['GroupId']
    ec2.authorize_security_group_ingress(
        GroupId=sg_id,
        IpPermissions=[
            {'IpProtocol': 'tcp', 'FromPort': 22, 'ToPort': 22, 'IpRanges': [{'CidrIp': '0.0.0.0/0'}]},
            {'IpProtocol': 'icmp', 'FromPort': -1, 'ToPort': -1, 'IpRanges': [{'CidrIp': '0.0.0.0/0'}]}
        ]
    )
    return sg_id

def crear_internet_gateway(vpc_id):
    ec2 = boto3.client('ec2')
    igw = ec2.create_internet_gateway()
    igw_id = igw['InternetGateway']['InternetGatewayId']
    ec2.create_tags(Resources=[igw_id], Tags=[{'Key': 'Name', 'Value': 'my-igwalex3'}])
    ec2.attach_internet_gateway(InternetGatewayId=igw_id, VpcId=vpc_id)
    return igw_id

def crear_route_table_publica(vpc_id, igw_id, subnet_id):
    ec2 = boto3.client('ec2')
    rt = ec2.create_route_table(VpcId=vpc_id)
    rt_id = rt['RouteTable']['RouteTableId']
    ec2.create_route(RouteTableId=rt_id, DestinationCidrBlock='0.0.0.0/0', GatewayId=igw_id)
    ec2.associate_route_table(RouteTableId=rt_id, SubnetId=subnet_id)
    return rt_id

def crear_nat_gateway(subnet_id):
    ec2 = boto3.client('ec2')
    eip = ec2.allocate_address(Domain='vpc')
    nat = ec2.create_nat_gateway(SubnetId=subnet_id, AllocationId=eip['AllocationId'])
    nat_id = nat['NatGateway']['NatGatewayId']
    # Esperar a que el NAT Gateway esté disponible
    ec2.get_waiter('nat_gateway_available').wait(NatGatewayIds=[nat_id])
    return nat_id

def crear_route_table_privada(vpc_id, nat_id, subnet_id):
    ec2 = boto3.client('ec2')
    rt = ec2.create_route_table(VpcId=vpc_id)
    rt_id = rt['RouteTable']['RouteTableId']
    ec2.create_route(RouteTableId=rt_id, DestinationCidrBlock='0.0.0.0/0', NatGatewayId=nat_id)
    ec2.associate_route_table(RouteTableId=rt_id, SubnetId=subnet_id)
    return rt_id

def lanzar_ec2(nombre, ami, tipo, subnet_id, keyname, sg_id, publica=False):
    ec2 = boto3.client('ec2')
    interface = [{
        'DeviceIndex': 0,
        'SubnetId': subnet_id,
        'Groups': [sg_id],
        'AssociatePublicIpAddress': publica
    }] if publica else None

    args = dict(
        ImageId=ami,
        InstanceType=tipo,
        KeyName=keyname,
        SecurityGroupIds=[sg_id],
        MinCount=1,
        MaxCount=1,
        TagSpecifications=[{
            'ResourceType': 'instance',
            'Tags': [{'Key': 'Name', 'Value': nombre}]
        }],
        SubnetId=subnet_id
    )

    if publica:
        args['NetworkInterfaces'] = interface
        args.pop('SecurityGroupIds')
        args.pop('SubnetId')

    instancia = ec2.run_instances(**args)
    return instancia['Instances'][0]['InstanceId']

# -------------------------------
# SCRIPT PRINCIPAL
# -------------------------------
if __name__ == "__main__":
    REGION = 'us-east-1'  # Cambia según tu región
    AMI = 'ami-0c94855ba95c71c99'  # Cambia por tu AMI
    KEY_NAME = 'vockey'  # Cambia por tu keypair
    INSTANCE_TYPE = 't2.micro'

    # Crear VPC
    vpc_id = crear_vpc()
    print("VPC creada:", vpc_id)

    # Subred pública
    subnet_pub_id = crear_subred(vpc_id, '172.16.1.0/24', 'us-east-1a', 'subred-publica')
    ip_publica_subred(subnet_pub_id)
    print("Subred pública creada:", subnet_pub_id)

    # Subred privada
    subnet_priv_id = crear_subred(vpc_id, '172.16.2.0/24', 'us-east-1b', 'subred-privada')
    print("Subred privada creada:", subnet_priv_id)

    # Security Group
    sg_id = crear_security_group(vpc_id)
    print("Security Group creado:", sg_id)

    # Internet Gateway y route table pública
    igw_id = crear_internet_gateway(vpc_id)
    rt_pub_id = crear_route_table_publica(vpc_id, igw_id, subnet_pub_id)
    print("Internet Gateway creado:", igw_id)
    print("Route table pública creada:", rt_pub_id)

    # NAT Gateway en subred pública y route table privada
    nat_id = crear_nat_gateway(subnet_pub_id)
    rt_priv_id = crear_route_table_privada(vpc_id, nat_id, subnet_priv_id)
    print("NAT Gateway creado:", nat_id)
    print("Route table privada creada:", rt_priv_id)

    # Lanzar EC2 pública
    ec2_pub_id = lanzar_ec2('ec2-publica', AMI, INSTANCE_TYPE, subnet_pub_id, KEY_NAME, sg_id, publica=True)
    print("EC2 pública creada:", ec2_pub_id)

    # Lanzar EC2 privada
    ec2_priv_id = lanzar_ec2('ec2-privada', AMI, INSTANCE_TYPE, subnet_priv_id, KEY_NAME, sg_id, publica=False)
    print("EC2 privada creada:", ec2_priv_id)
