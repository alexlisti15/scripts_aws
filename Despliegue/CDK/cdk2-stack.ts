import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
// import * as sqs from 'aws-cdk-lib/aws-sqs';

export class Cdk2Stack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    //API gateway con rest api
    const api = new cdk.aws_apigateway.CfnRestApi(this, 'MyApi', {
      name: 'MyApi',
      description: 'API Gateway con CDK',
    });

    //creo el recurso /hola
    const Helloresource = new cdk.aws_apigateway.CfnResource(this, 'MyResource', {
      parentId: api.attrRootResourceId,
      pathPart: 'hola',
      restApiId: api.ref,
    });

    //creo el metodo GET para el recurso /hola
    const helloMethod =new cdk.aws_apigateway.CfnMethod(this, 'MyMethod', {
      httpMethod: 'GET',
      resourceId: Helloresource.ref,
      restApiId: api.ref,
      authorizationType: 'NONE',
      integration: {
        type: 'MOCK',
        requestTemplates: {
          'application/json': '{"statusCode": 200}',
        },
      },
    });

  const despliegue = new cdk.aws_apigateway.CfnDeployment(this, 'MyDeployment', {
    restApiId: api.ref,
  });


  despliegue.addDependency(Helloresource); // o el método, para asegurar que la deployment incluya recursos
  despliegue.addDependency(helloMethod); // para asegurar que la deployment se cree después de la API

  new cdk.CfnOutput(this, 'ApiEndpoint', {
    value: `https://${api.ref}.execute-api.${this.region}.amazonaws.com/produccion/hola`,
    description: 'Endpoint de la API Gateway',
  });






    /*Lambda con construct nivel 1

    const lambdaRole = new cdk.aws_iam.Role(this, 'LambdaRole', {
      assumedBy: new cdk.aws_iam.ServicePrincipal('lambda.amazonaws.com'),
      managedPolicies: [cdk.aws_iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AWSLambdaBasicExecutionRole')],
    });



    new cdk.aws_lambda.CfnFunction(this,'HolaLambda',{
      functionName: "HolaMundoLambda",
      runtime: "nodejs18.x",
      handler: "index.handler",
      role: lambdaRole.roleArn,
      code: {
        zipFile: 'exports.handler = async () => ({ statusCode: 200, body: JSON.stringify({ message: "HolaMundoLambda" }) });'
      }

    });*/



    /*construct nivel 1 para s3
    new cdk.aws_s3.CfnBucket(this, "MyFirstBucket", {
        bucketName: "myfirstbucket-alegarmar24",

      });
      */

    //constructor L2 para crear Bucket
     /*const bucket = new cdk.aws_s3.Bucket(this, "MyFirstBucket", {
       bucketName: "mysecondbucket-alegarmar24"

      });

    //subir un archivo al bucket
    new cdk.aws_s3_deployment.BucketDeployment(this, "DeployFiles", {
        sources: [cdk.aws_s3_deployment.Source.asset("./assets")],
        destinationBucket: bucket
      });


  }
}
*/
    //construct nivel 1 para dynamo
    /*
        new cdk.aws_dynamodb.CfnTable(this, "MiTabla", {
      tableName: "MyFirstTable-alegarmar24",
      billingMode: "PAY_PER_REQUEST",

      attributeDefinitions: [
        {
          attributeName: "nombre",
          attributeType: "S"
        }
      ],

      keySchema: [
        {
          attributeName: "nombre",
          keyType: "HASH"
        }
      ],
    });

*/

    }
  }
