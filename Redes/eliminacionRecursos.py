import boto3
import time
from botocore.exceptions import ClientError

def eliminar_recursos_vpc(vpc_id):
    ec2_resource = boto3.resource('ec2')
    ec2_client = boto3.client('ec2')
    vpc = ec2_resource.Vpc(vpc_id)

    print(f"--- Iniciando limpieza profunda de VPC: {vpc_id} ---")

    # 1. Terminar Instancias EC2
    instances = list(vpc.instances.all())
    if instances:
        ids = [i.id for i in instances]
        print(f"Terminando instancias: {ids}")
        vpc.instances.terminate()
        
        # Esperar a que se terminen (importante para liberar ENIs)
        print("Esperando a que las instancias se detengan por completo...")
        waiter = ec2_client.get_waiter('instance_terminated')
        waiter.wait(InstanceIds=ids)

    # 2. Eliminar Network Interfaces (ENIs)
    for subnet in vpc.subnets.all():
        for eni in subnet.network_interfaces.all():
            print(f"Eliminando ENI: {eni.id}")
            eni.detach() if eni.attachment else None
            eni.delete()

    # 3. Eliminar NAT Gateways (si existen)
    for subnet in vpc.subnets.all():
        nat_gateways = ec2_client.describe_nat_gateways(
            Filters=[{'Name': 'subnet-id', 'Values': [subnet.id]}]
        )['NatGateways']
        for nat in nat_gateways:
            if nat['State'] != 'deleted':
                print(f"Eliminando NAT Gateway: {nat['NatGatewayId']}")
                ec2_client.delete_nat_gateway(NatGatewayId=nat['NatGatewayId'])

    # 4. Eliminar Internet Gateways
    for igw in vpc.internet_gateways.all():
        print(f"Desacoplando y eliminando IGW: {igw.id}")
        vpc.detach_internet_gateway(InternetGatewayId=igw.id)
        igw.delete()

    # 5. Eliminar Subredes
    for subnet in vpc.subnets.all():
        print(f"Eliminando Subnet: {subnet.id}")
        subnet.delete()

    # 6. Eliminar Security Groups (excepto el default)
    for sg in vpc.security_groups.all():
        if sg.group_name != 'default':
            print(f"Eliminando Security Group: {sg.id}")
            try:
                sg.delete()
            except ClientError:
                print(f"Reintentando eliminar SG {sg.id} más tarde...")

    # 7. Finalmente, eliminar la VPC
    try:
        vpc.delete()
        print(f"\n¡Éxito! VPC {vpc_id} ha sido eliminada.")
    except Exception as e:
        print(f"Error final al borrar VPC: {e}")

if __name__ == "__main__":
    ID_DE_TU_VPC = 'vpc-xxxxxxxxxxxx' 
    eliminar_recursos_vpc(ID_DE_TU_VPC)