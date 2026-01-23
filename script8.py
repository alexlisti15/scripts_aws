import boto3
import time

ec2 = boto3.client('ec2')

# -------------------------------
# FUNCIONES
# -------------------------------

def crear_vpc():
    vpc = ec2.create_vpc(CidrBlock='10.10.0.0/16')
    vpc_id = vpc['Vpc']['VpcId']
    ec2.modify_vpc_attribute(VpcId=vpc_id, EnableDnsSupport={'Value': True})
    ec2.modify_vpc_attribute(VpcId=vpc_id, EnableDnsHostnames={'Value': True})
    ec2.create_tags(Resources=[vpc_id], Tags=[{'Key': 'Name', 'Value': 'VPC-CUSTOM'}])
    return vpc_id

def crear_subred(vpc_id, cidr, az, nombre, publica=False):
    sub = ec2.create_subnet(VpcId=vpc_id, CidrBlock=cidr, AvailabilityZone=az)
    sub_id = sub['Subnet']['SubnetId']
    ec2.create_tags(Resources=[sub_id], Tags=[{'Key': 'Name', 'Value': nombre}])
    if publica:
        ec2.modify_subnet_attribute(SubnetId=sub_id, MapPublicIpOnLaunch={'Value': True})
    return sub_id

def crear_security_groups(vpc_id):
    # SG-PUBLICA → permite SSH y web desde 0.0.0.0/0
    sg_pub = ec2.create_security_group(
        GroupName='SG-PUBLIC',
        Description='Acceso SSH y web',
        VpcId=vpc_id
    )
    sg_pub_id = sg_pub['GroupId']

    ec2.authorize_security_group_ingress(
        GroupId=sg_pub_id,
        IpPermissions=[
            {'IpProtocol': 'tcp', 'FromPort': 22,  'ToPort': 22,  'IpRanges': [{'CidrIp': '0.0.0.0/0'}]},
            {'IpProtocol': 'tcp', 'FromPort': 80,  'ToPort': 80,  'IpRanges': [{'CidrIp': '0.0.0.0/0'}]},
            {'IpProtocol': 'tcp', 'FromPort': 443, 'ToPort': 443, 'IpRanges': [{'CidrIp': '0.0.0.0/0'}]}
        ]
    )

    # SG-PRIVADA → SOLO permite tráfico desde SG-PUBLICA
    sg_priv = ec2.create_security_group(
        GroupName='SG-PRIVATE',
        Description='Acceso SOLO desde SG-PUBLIC',
        VpcId=vpc_id
    )
    sg_priv_id = sg_priv['GroupId']

    ec2.authorize_security_group_ingress(
        GroupId=sg_priv_id,
        IpPermissions=[
            {'IpProtocol': '-1',
             'UserIdGroupPairs': [{'GroupId': sg_pub_id}]}
        ]
    )

    return sg_pub_id, sg_priv_id


def crear_internet_gateway(vpc_id):
    igw = ec2.create_internet_gateway()
    igw_id = igw['InternetGateway']['InternetGatewayId']
    ec2.attach_internet_gateway(InternetGatewayId=igw_id, VpcId=vpc_id)
    return igw_id

def crear_route_table(vpc_id, nombre):
    rt = ec2.create_route_table(VpcId=vpc_id)
    rt_id = rt['RouteTable']['RouteTableId']
    ec2.create_tags(Resources=[rt_id], Tags=[{'Key': 'Name', 'Value': nombre}])
    return rt_id

def asociar_rt(rt_id, subnet_id):
    ec2.associate_route_table(RouteTableId=rt_id, SubnetId=subnet_id)

def crear_nat_gateway(subnet_publica):
    eip = ec2.allocate_address(Domain='vpc')
    nat = ec2.create_nat_gateway(SubnetId=subnet_publica, AllocationId=eip['AllocationId'])
    nat_id = nat['NatGateway']['NatGatewayId']
    ec2.get_waiter('nat_gateway_available').wait(NatGatewayIds=[nat_id])
    return nat_id

def crear_nacl_publica(vpc_id, subredes):
    nacl = ec2.create_network_acl(VpcId=vpc_id)
    nacl_id = nacl['NetworkAcl']['NetworkAclId']
    ec2.create_tags(Resources=[nacl_id], Tags=[{'Key': 'Name', 'Value': 'NACL-PUBLICA'}])

    # Reglas públicas: SSH, HTTP, HTTPS
    reglas = [
        (100, 'tcp', 22), (110, 'tcp', 80), (120, 'tcp', 443)
    ]

    for (rule_number, protocol, port) in reglas:
        ec2.create_network_acl_entry(
            NetworkAclId=nacl_id,
            RuleNumber=rule_number,
            Protocol='6',
            RuleAction='allow',
            Egress=False,
            PortRange={'From': port, 'To': port},
            CidrBlock='0.0.0.0/0'
        )

    for subnet in subredes:
        ec2.associate_network_acl(NetworkAclId=nacl_id, SubnetId=subnet)

    return nacl_id

def crear_nacl_privada(vpc_id, subredes):
    nacl = ec2.create_network_acl(VpcId=vpc_id)
    nacl_id = nacl['NetworkAcl']['NetworkAclId']
    ec2.create_tags(Resources=[nacl_id], Tags=[{'Key': 'Name', 'Value': 'NACL-PRIVADA'}])

    # DENY inbound from 0.0.0.0/0
    ec2.create_network_acl_entry(
        NetworkAclId=nacl_id,
        RuleNumber=100,
        Protocol='-1',
        RuleAction='deny',
        Egress=False,
        CidrBlock='0.0.0.0/0'
    )

    # Allow outbound (needed for NAT)
    ec2.create_network_acl_entry(
        NetworkAclId=nacl_id,
        RuleNumber=100,
        Protocol='-1',
        RuleAction='allow',
        Egress=True,
        CidrBlock='0.0.0.0/0'
    )

    for subnet in subredes:
        ec2.associate_network_acl(NetworkAclId=nacl_id, SubnetId=subnet)

    return nacl_id

# -------------------------------
# SCRIPT PRINCIPAL
# -------------------------------
if __name__ == "__main__":
    REGION = 'us-east-1'
    AMI = 'ami-0c94855ba95c71c99'
    KEY_NAME = 'vockey'
    INSTANCE_TYPE = 't2.micro'

    vpc_id = crear_vpc()
    print("VPC:", vpc_id)

    # Crear subredes
    subnet_pub1 = crear_subred(vpc_id, '10.10.1.0/24', 'us-east-1a', 'publica-1', True)
    subnet_pub2 = crear_subred(vpc_id, '10.10.2.0/24', 'us-east-1b', 'publica-2', True)

    subnet_priv1 = crear_subred(vpc_id, '10.10.3.0/24', 'us-east-1a', 'privada-1')
    subnet_priv2 = crear_subred(vpc_id, '10.10.4.0/24', 'us-east-1b', 'privada-2')

    print("Subredes creadas.")

    # SG encadenados
    sg_pub, sg_priv = crear_security_groups(vpc_id)

    # IGW
    igw_id = crear_internet_gateway(vpc_id)

    # RT públicas
    rt_pub1 = crear_route_table(vpc_id, "RT-PUBLICA-1")
    ec2.create_route(RouteTableId=rt_pub1, GatewayId=igw_id, DestinationCidrBlock='0.0.0.0/0')
    asociar_rt(rt_pub1, subnet_pub1)

    rt_pub2 = crear_route_table(vpc_id, "RT-PUBLICA-2")
    ec2.create_route(RouteTableId=rt_pub2, GatewayId=igw_id, DestinationCidrBlock='0.0.0.0/0')
    asociar_rt(rt_pub2, subnet_pub2)

    # NAT Gateway
    nat_id = crear_nat_gateway(subnet_pub1)

    # RT privadas
    rt_priv1 = crear_route_table(vpc_id, "RT-PRIVADA-1")
    ec2.create_route(RouteTableId=rt_priv1, NatGatewayId=nat_id, DestinationCidrBlock='0.0.0.0/0')
    asociar_rt(rt_priv1, subnet_priv1)

    rt_priv2 = crear_route_table(vpc_id, "RT-PRIVADA-2")
    ec2.create_route(RouteTableId=rt_priv2, NatGatewayId=nat_id, DestinationCidrBlock='0.0.0.0/0')
    asociar_rt(rt_priv2, subnet_priv2)

    # NACLs
    crear_nacl_publica(vpc_id, [subnet_pub1, subnet_pub2])
    crear_nacl_privada(vpc_id, [subnet_priv1, subnet_priv2])

    print("Todo creado correctamente.")
