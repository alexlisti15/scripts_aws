import boto3

def crear_vpc():
    # Crear Cliente de EC2
    ec2 = boto3.client('ec2')

    # Crear la VPC
    vpc = ec2.create_vpc(CidrBlock='172.16.0.1/16')
    vpc_id = vpc['Vpc']['VpcId']
    print(f" VPC creada con ID: {vpc_id}")

    # Habilitar DNS support
    ec2.modify_vpc_attribute(
        VpcId=vpc_id,
        EnableDnsSupport={'Value': True}
    )

    # Habilitar DNS hostnames
    ec2.modify_vpc_attribute(
        VpcId=vpc_id,
        EnableDnsHostnames={'Value': True}
    )

    # Etiquetar la VPC (opcional)
    ec2.create_tags(
        Resources=[vpc_id],
        Tags=[{'Key': 'Name', 'Value': 'MiVPC-Boto3'}]
    )

    print(" DNS habilitado y etiqueta 'MiVPC-Boto3' asignada.")
    return vpc_id


if __name__ == "__main__":
    vpc_id = crear_vpc()
    print(f" Proceso completado. ID de la VPC: {vpc_id}")

def crear_subnet(vpc_id):
   # Crear Cliente de EC2
    ec2 = boto3.client('ec2')

    # Crear la Subnet
    subnet = ec2.create_subnet(
        CidrBlock='172.16.1.0/24',
        VpcId=vpc_id
    )
    subnet_id = subnet['Subnet']['SubnetId']
    print(f" Subnet creada con ID: {subnet_id}")

    # Etiquetar la Subnet (opcional)
    ec2.create_tags(
        Resources=[subnet_id],
        Tags=[{'Key': 'Name', 'Value': 'MiSubnetAGM'}]
    )

    print(" Etiqueta 'MiSubnetAGM' asignada.")
    return subnet_id

    if __name__ == "__main__":
        subnet_id = crear_subnet(vpc_id)
        print(f" Proceso completado. ID de la Subnet: {subnet_id}")
