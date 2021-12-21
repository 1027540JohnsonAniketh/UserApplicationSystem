# UserApplicationSystem
<br>
# This repository contains all the codebase for the backend of UserApplicationSystem.
<br>
## The application has the following restful endpoints:
<br>
1)**Create a user**                               : /v1/users
<br>
2)**Get a user**                                  : /v1/users/{username}
<br>
3)**Update a user**                               : /v1/users/{usernmae}
<br>
4)**Create a user profile image in S3 bucket**    : /v1/users/{username}/{imagename}
<br>
5)**Get a user's profile image**                  : /v1/users/{username}/{imagename}
<br>
6)**Update a user's profile image**               : /v1/users/{username}/{imagename}
<br>
7)**Delete a user's profile image**               : /v1/users/{username}/{imagename}
<br>
<br>
## The entire repository is further divided 5 repos:
<br>
1)**webapp**:This repo has all the code of backend web application and is developed using:
<br>
  a)Java
  <br>
  b)Spring Boot
  <br>
  c)Spring Security
  <br>
  d)MySQL
  <br>
  e)StatsD
  <br>
  f)AWS EC2,RDS,S3,Certification Manager,Route 53,CloudWatch,KMS
  <br>
2)**ami**:This repo has the code for building the AMI using packer and to automate the entire application I used Github actions.
<br>
3)**infrastructure**:This repo has the code for provisioning AWS resources using Terraform.
<br>
4)**app-cicd**:This repo has the code for implementing CI/CD for the webapplication and the final application is deployed in the AWS EC2 instance.
<br>
5)**serverless**:This repo has the code for implementing a simple email feature which gets triggered whenever a new user is created and the user get's a mail for verfication.The application is developed using JavaScript,AWS SNS,SES,DynamoDB.
<br>
