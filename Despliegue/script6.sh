#!/bin/bash
set -e

# -------------------------------
# Configuración
# -------------------------------
APP_NAME="APPgreenBlue2"
BLUE_ENV="MiApp-Blue4"
GREEN_ENV="MiApp-Green4"
PLATFORM="64bit Amazon Linux 2023 v4.7.8 running PHP 8.4"
CNAME_BLUE="miappagm-blue4"
CNAME_GREEN="miappagm-green4"
INSTANCE_TYPE="t3.micro"
SERVICE_ROLE="LabRole"
INSTANCE_PROFILE="LabInstanceProfile"
S3_BUCKET="appgreenblue-bucket"
APP_ZIP="index.zip"
APP_ZIP_V2="index2.zip"
VERSION_BLUE="v1"
VERSION_GREEN="v2"

# -------------------------------
# 1️⃣ Crear bucket S3
# -------------------------------
echo "Creando bucket S3: $S3_BUCKET"
aws s3 mb s3://$S3_BUCKET

# -------------------------------
# 2️⃣ Crear aplicación en EB
# -------------------------------
echo "Creando aplicación Elastic Beanstalk: $APP_NAME"
aws elasticbeanstalk create-application \
    --application-name $APP_NAME \
    --description "Aplicación Blue/Green PHP 8.4"

# -------------------------------
# 3️⃣ Subir versión inicial a S3
# -------------------------------
echo "Subiendo $APP_ZIP a S3"
aws s3 cp $APP_ZIP s3://$S3_BUCKET/$APP_ZIP

# -------------------------------
# 4️⃣ Crear versión de la aplicación (v1)
# -------------------------------
echo "Creando versión $VERSION_BLUE"
aws elasticbeanstalk create-application-version \
    --application-name $APP_NAME \
    --version-label $VERSION_BLUE \
    --source-bundle S3Bucket=$S3_BUCKET,S3Key=$APP_ZIP

# -------------------------------
# 5️⃣ Crear entorno Blue (producción actual)
# -------------------------------
echo "Creando entorno Blue: $BLUE_ENV"
aws elasticbeanstalk create-environment \
  --application-name $APP_NAME \
  --environment-name $BLUE_ENV \
  --solution-stack-name "$PLATFORM" \
  --cname-prefix $CNAME_BLUE \
  --version-label $VERSION_BLUE \
  --option-settings \
    Namespace=aws:autoscaling:launchconfiguration,OptionName=InstanceType,Value=$INSTANCE_TYPE \
    Namespace=aws:autoscaling:launchconfiguration,OptionName=IamInstanceProfile,Value=$INSTANCE_PROFILE \
    Namespace=aws:elasticbeanstalk:environment,OptionName=ServiceRole,Value=$SERVICE_ROLE 

# -------------------------------
# 6️⃣ Subir nueva versión para Green
# -------------------------------
echo "Subiendo $APP_ZIP_V2 a S3"
aws s3 cp $APP_ZIP_V2 s3://$S3_BUCKET/$APP_ZIP_V2

echo "Creando versión $VERSION_GREEN"
aws elasticbeanstalk create-application-version \
    --application-name $APP_NAME \
    --version-label $VERSION_GREEN \
    --source-bundle S3Bucket=$S3_BUCKET,S3Key=$APP_ZIP_V2

# -------------------------------
# 7️⃣ Crear entorno Green (nuevo despliegue)
# -------------------------------
echo "Creando entorno Green: $GREEN_ENV"
aws elasticbeanstalk create-environment \
  --application-name $APP_NAME \
  --environment-name $GREEN_ENV \
  --solution-stack-name "$PLATFORM" \
  --cname-prefix $CNAME_GREEN \
  --version-label $VERSION_GREEN \
  --option-settings \
    Namespace=aws:autoscaling:launchconfiguration,OptionName=InstanceType,Value=$INSTANCE_TYPE \
    Namespace=aws:autoscaling:launchconfiguration,OptionName=IamInstanceProfile,Value=$INSTANCE_PROFILE \
    Namespace=aws:elasticbeanstalk:environment,OptionName=ServiceRole,Value=$SERVICE_ROLE 

# -------------------------------
# 8️⃣ Swap de CNAMEs (Blue ↔ Green)
# -------------------------------
echo "Haciendo swap de CNAMEs"
aws elasticbeanstalk swap-environment-cnames \
    --source-environment-name $BLUE_ENV \
    --destination-environment-name $GREEN_ENV

echo "✅ Despliegue Blue/Green completado"
