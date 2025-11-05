#!/bin/bash
set -e

# ======================================================
# 1️⃣ Obtener ID de la VPC por defecto
# ======================================================
VpcId=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text)
echo "VPC por defecto: $VpcId"

# ======================================================
# 2️⃣ Obtener IDs de las subredes por defecto de esa VPC
# ======================================================
SubnetsId=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VpcId" \
    --query "Subnets[].SubnetId" \
    --output text)
echo "Subredes por defecto: $SubnetsId"

# ======================================================
# 3️⃣ Crear grupo de seguridad para HTTP
# ======================================================
GroupID=$(aws ec2 create-security-group \
    --group-name sgAlex3 \
    --description "Grupo de seguridad para NLB HTTP" \
    --vpc-id $VpcId \
    --query 'GroupId' \
    --output text)
echo "Grupo de seguridad creado: $GroupID"

# ======================================================
# 4️⃣ Agregar regla para permitir tráfico HTTP (puerto 80)
# ======================================================
aws ec2 authorize-security-group-ingress \
    --group-id $GroupID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0
echo "Regla HTTP añadida al grupo de seguridad $GroupID"

# ======================================================
# 5️⃣ Crear Target Group para el NLB
# ======================================================
TG_ARN=$(aws elbv2 create-target-group \
    --name tg-http \
    --protocol TCP \
    --port 80 \
    --vpc-id $VpcId \
    --target-type instance \
    --query "TargetGroups[0].TargetGroupArn" \
    --output text)
echo "Target Group creado: $TG_ARN"

# ======================================================
# 6️⃣ Registrar las instancias en el Target Group
# ======================================================
aws elbv2 register-targets \
    --target-group-arn $TG_ARN \
    --targets Id=i-0f85dbb4137ece96a Id=i-07cf0bb3117028c6b
echo "Instancias registradas al Target Group"

# ======================================================
# 7️⃣ Crear el Network Load Balancer
# ======================================================
NLB_ARN=$(aws elbv2 create-load-balancer \
    --name mi2-nlb-http \
    --type network \
    --subnets $SubnetsId \
    --scheme internet-facing \
    --query "LoadBalancers[0].LoadBalancerArn" \
    --output text)
echo "Network Load Balancer creado: $NLB_ARN"

# ======================================================
# 8️⃣ Crear Listener para el NLB
# ======================================================
aws elbv2 create-listener \
    --load-balancer-arn $NLB_ARN \
    --protocol TCP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN
echo "Listener TCP:80 creado y asociado al Target Group"

# ======================================================
# 9️⃣ Mostrar DNS del NLB
# ======================================================
aws elbv2 describe-load-balancers \
    --names mi2-nlb-http \
    --query "LoadBalancers[0].DNSName" \
    --output text
