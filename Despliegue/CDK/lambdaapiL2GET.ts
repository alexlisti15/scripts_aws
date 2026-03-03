import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as lambda from 'aws-cdk-lib/aws-lambda';

export class Cdk2Stack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // 1. Lambda L2
    const helloFn = new lambda.Function(this, 'HelloFunction', {
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        exports.handler = async () => ({
          statusCode: 200,
          body: JSON.stringify({ message: 'Hello from CDK L2!' }),
        });
      `),
    });

    // 2. API Gateway L2 (Crea API, Deployment y Stage)
    const api = new apigateway.RestApi(this, 'HelloRestApi', {
      deployOptions: { stageName: 'produc' },
    });

    // 3. Recurso y Método (Gestiona permisos e integración automáticamente)
    api.root.addResource('hello')
            .addMethod('GET', new apigateway.LambdaIntegration(helloFn));

    // 4. Output simplificado
    new cdk.CfnOutput(this, 'HelloEndpoint', {
      value: api.urlForPath('/hello'),
    });
  }
}
