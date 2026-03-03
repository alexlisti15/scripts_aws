


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
