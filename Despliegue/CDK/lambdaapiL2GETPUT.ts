import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as lambda from 'aws-cdk-lib/aws-lambda';

export class Cdk2Stack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // ─── 1. DEFINICIÓN DE LAMBDAS ─────────────────────────────────────────────

    // Lambda para el GET
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

    // Lambda para el PUT (Saludo personalizado)
    const greetFn = new lambda.Function(this, 'GreetFunction', {
      runtime: lambda.Runtime.NODEJS_20_X,
      handler: 'index.handler',
      code: lambda.Code.fromInline(`
        exports.handler = async (event) => {
          const name = event.pathParameters.name || 'Desconocido';
          return {
            statusCode: 200,
            body: JSON.stringify({ message: \`Hola \${name}, saludos desde L2!\` }),
          };
        };
      `),
    });

    // ─── 2. REST API ──────────────────────────────────────────────────────────
    const api = new apigateway.RestApi(this, 'HelloApiL2', {
      restApiName: 'HelloApi-L2',
      deployOptions: { stageName: 'produc' },
    });

    // ─── 3. RECURSOS Y MÉTODOS ────────────────────────────────────────────────

    // Ruta: /hello
    const helloResource = api.root.addResource('hello');
    helloResource.addMethod('GET', new apigateway.LambdaIntegration(helloFn));

    // Ruta: /hello/{name}
    const nameResource = helloResource.addResource('{name}');
    nameResource.addMethod('PUT', new apigateway.LambdaIntegration(greetFn));

    // ─── 4. OUTPUTS ──────────────────────────────────────────────────────────
    new cdk.CfnOutput(this, 'GetUrl', { value: api.urlForPath('/hello') });
    new cdk.CfnOutput(this, 'PutUrl', { value: api.urlForPath('/hello/AlexG') });
  }
}
