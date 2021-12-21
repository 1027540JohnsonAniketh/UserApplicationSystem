var AWS = require("aws-sdk");
var dynamoDB = new AWS.DynamoDB.DocumentClient({ region: 'us-west-2' });
var crypto = require("crypto");
var ses = new AWS.SES({ region: 'us-west-2' });
exports.lambda_handler = (event, context, callback) => {
    console.log("Hola");
    let currentTime = Math.round(new Date().getTime()/1000);
    let expirationTime = (currentTime + 120).toString();
    var message=event.Records[0].Sns.Message
    var words=message.split(' ')
    var email=words[0]
    var token=words[1]
    var msgType=words[2]
    var getParams = {
        Key: {
            "id":email
        },
        TableName: 'dynamodb_instance'
    };
    dynamoDB.get(getParams, function (error, getdata) {
        var jsString = JSON.stringify(getdata);
        if (error) {
            console.log("Error",error);
        }
        else {
            if (Object.keys(getdata).length >= 0) {
                var flag = false;
                if(getdata.Item == undefined){flag = true;}else
                    if(getdata.Item.timeStamp < (new Date).getTime()){flag = true;}
                if(flag){
                    var putParams = {
                        Item: {
                            "id":email,
                            "OPT":token,
                            "MessageType":msgType,
                            "TimeToExist":parseInt(expirationTime)
                        },
                        TableName: 'dynamodb_instance'
                    };
                    dynamoDB.put(putParams, function (err, data) {
                        if (err) {
                            callback(err, null);
                        } else {
                            callback(null, data);
                            var emailParams = {
                                Destination: {
                                    ToAddresses: [email]
                                },
                                Message: {
                                    Body: {
                                        Text: {
                                            Data: "https://prod.njaniketh.me/cloud/v1/users/verifyUserEmail/"+email
                                        }
                                    },
                                    Subject: {
                                        Data: "User Verification URL"
                                    }
                                },
                                Source: "noreply@"+"prod.njaniketh.me"
                            };
                            ses.sendEmail(emailParams, function (err, data) {
                                if (err) {
                                    console.log(err);
                                }
                                else {
                                    console.log("EMAIL SENT");
                                    context.succeed(event);
                                }
                            });
                        }
                    });
                }
            } else
                console.log(getdata, "User exists");
        }
    });
};