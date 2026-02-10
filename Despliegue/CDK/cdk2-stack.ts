import * as cdk from 'aws-cdk-lib';
import { Construct } from 'constructs';
// import * as sqs from 'aws-cdk-lib/aws-sqs';

export class Cdk2Stack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    /*construct nivel 1 para s3
    new cdk.aws_s3.CfnBucket(this, "MyFirstBucket", {
        bucketName: "myfirstbucket-alegarmar24",
        
      });
      */

    //constructor L2 para crear Bucket
     const bucket = new cdk.aws_s3.Bucket(this, "MyFirstBucket", {
       bucketName: "mysecondbucket-alegarmar24"

      });

    //subir un archivo al bucket
    new cdk.aws_s3_deployment.BucketDeployment(this, "DeployFiles", {
        sources: [cdk.aws_s3_deployment.Source.asset("./assets")],
        destinationBucket: bucket
      });

    //constructor L3 - patrón de alto nivel para S3 con CloudFront
    new cdk.aws_cloudfront.CloudFrontWebDistribution(this, "MyDistribution", {
      originConfigs: [{
        s3OriginSource: {
          s3BucketSource: bucket
        },
        behaviors: [{ isDefaultBehavior: true }]
      }]
    });
    
  
  }
}
