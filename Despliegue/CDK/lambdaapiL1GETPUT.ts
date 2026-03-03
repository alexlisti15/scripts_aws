import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
import * as apigateway from 'aws-cdk-lib/aws-apigateway';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as iam from 'aws-cdk-lib/aws-iam';

export class Cdk2Stack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // ─── 1. ROL DE IAM (Reutilizado para ambas Lambdas) ──────────────────────
    const lambdaRole = new iam.CfnRole(this, 'LambdaRole', {
      assumeRolePolicyDocument: {
        Version: '2012-10-17',
        Statement: [{
          Effect: 'Allow',
          Principal: { Service: 'lambda.amazonaws.com' },
          Action: 'sts:AssumeRole',
        }],
      },
      managedPolicyArns: [
        'arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole',
      ],
    });

    // ─── 2. LAMBDA GET (Original) ─────────────────────────────────────────────
    const helloFn = new lambda.CfnFunction(this, 'HelloFunction', {
      functionName: 'hello-handler',
      runtime: 'nodejs20.x',
      handler: 'index.handler',
      role: lambdaRole.attrArn,
      code: {
        zipFile: `
exports.handler = async () => ({
  statusCode: 200,
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ message: 'Hello from CDK L1!' }),
});`,
      },
    });

    // ─── 3. LAMBDA PUT (Nueva - Saludo personalizado) ────────────────────────
    const greetFn = new lambda.CfnFunction(this, 'GreetFunction', {
      functionName: 'greet-handler',
      runtime: 'nodejs20.x',
      handler: 'index.handler',
      role: lambdaRole.attrArn,
      code: {
        zipFile: `
exports.handler = async (event) => {
  const name = event.pathParameters.name || 'Desconocido';
  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message: \`Hola \${name}, ¡saludos desde el PUT de L1!\` }),
  };
};`,
      },
    });

    // ─── 4. REST API ──────────────────────────────────────────────────────────
    const restApi = new apigateway.CfnRestApi(this, 'HelloRestApi', {
      name: 'HelloApi',
      description: 'API REST desplegada con constructores L1',
    });

    // ─── 5. RECURSO /hello ────────────────────────────────────────────────────
    const helloResource = new apigateway.CfnResource(this, 'HelloResource', {
      restApiId: restApi.ref,
      parentId: restApi.attrRootResourceId,
      pathPart: 'hello',
    });

    // ─── 6. RECURSO /hello/{name} (Nuevo) ─────────────────────────────────────
    const nameResource = new apigateway.CfnResource(this, 'NameResource', {
      restApiId: restApi.ref,
      parentId: helloResource.ref, // Cuelga de /hello
      pathPart: '{name}',          // Parámetro de ruta
    });

    // ─── 7. MÉTODO GET /hello ─────────────────────────────────────────────────
    const getMethod = new apigateway.CfnMethod(this, 'HelloGetMethod', {
      restApiId: restApi.ref,
      resourceId: helloResource.ref,
      httpMethod: 'GET',
      authorizationType: 'NONE',
      integration: {
        type: 'AWS_PROXY',
        integrationHttpMethod: 'POST',
        uri: `arn:aws:apigateway:${this.region}:lambda:path/2015-03-31/functions/${helloFn.attrArn}/invocations`,
      },
    });

    // ─── 8. MÉTODO PUT /hello/{name} (Nuevo) ──────────────────────────────────
    const putMethod = new apigateway.CfnMethod(this, 'GreetPutMethod', {
      restApiId: restApi.ref,
      resourceId: nameResource.ref,
      httpMethod: 'PUT',
      authorizationType: 'NONE',
      integration: {
        type: 'AWS_PROXY',
        integrationHttpMethod: 'POST',
        uri: `arn:aws:apigateway:${this.region}:lambda:path/2015-03-31/functions/${greetFn.attrArn}/invocations`,
      },
    });

    // ─── 9. PERMISOS (Para ambas Lambdas) ─────────────────────────────────────
    new lambda.CfnPermission(this, 'ApiGwPermissionGet', {
      action: 'lambda:InvokeFunction',
      functionName: helloFn.attrArn,
      principal: 'apigateway.amazonaws.com',
      sourceArn: `arn:aws:execute-api:${this.region}:${this.account}:${restApi.ref}/*/GET/hello`,
    });

    new lambda.CfnPermission(this, 'ApiGwPermissionPut', {
      action: 'lambda:InvokeFunction',
      functionName: greetFn.attrArn,
      principal: 'apigateway.amazonaws.com',
      sourceArn: `arn:aws:execute-api:${this.region}:${this.account}:${restApi.ref}/*/PUT/hello/*`,
    });

    // ─── 10. DEPLOYMENT Y STAGE ───────────────────────────────────────────────
    const deployment = new apigateway.CfnDeployment(this, 'HelloDeployment', {
      restApiId: restApi.ref,
    });
    // Importante: El deployment debe esperar a que AMBOS métodos existan
    deployment.addDependency(getMethod);
    deployment.addDependency(putMethod);

    new apigateway.CfnStage(this, 'ProducStage', {
      restApiId: restApi.ref,
      deploymentId: deployment.ref,
      stageName: 'produc',
    });

    // ─── 11. OUTPUTS ──────────────────────────────────────────────────────────
    new cdk.CfnOutput(this, 'PutEndpoint', {
      description: 'Prueba el PUT con: curl -X PUT <URL>',
      value: `https://${restApi.ref}.execute-api.${this.region}.amazonaws.com/produc/hello/Alex`,
    });
  }
}
