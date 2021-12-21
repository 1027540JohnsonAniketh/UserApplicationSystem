# UserApplicationSystem
<pre>
This repository contains all the codebase for the backend of UserApplicationSystem.
The application has the following restful endpoints:
1)<b>Create a user</b>                               : /v1/users
2)<b>Get a user</b>                                  : /v1/users/{username}
3)<b>Update a user</b>                               : /v1/users/{usernmae}
4)<b>Create a user profile image in S3 bucket</b>    : /v1/users/{username}/{imagename}
5)<b>Get a user's profile image</b>                  : /v1/users/{username}/{imagename}
6)<b>Update a user's profile image</b>               : /v1/users/{username}/{imagename}
7)<b>Delete a user's profile image</b>               : /v1/users/{username}/{imagename}

The entire repository is further divided 5 repos:
1)<b>webapp</b>:This repo has all the code of backend web application and is developed using:
  a)Java
  b)Spring Boot
  c)Spring Security
  d)MySQL
  e)StatsD
  f)AWS EC2,RDS,S3,Certification Manager,Route 53,CloudWatch,KMS
2)<b>ami</b>:This repo has the code for building the AMI using packer and to automate the entire application I used Github actions.
3)<b>infrastructure</b>:This repo has the code for provisioning AWS resources using Terraform.
4)<b>app-cicd</b>:This repo has the code for implementing CI/CD for the webapplication and the final application is deployed in the AWS EC2 instance.
5)<b>serverless</b>:This repo has the code for implementing a simple email feature which gets triggered whenever a new user is created and the user get's a mail for verfication.The application is developed using JavaScript,AWS SNS,SES,DynamoDB.
</pre>
