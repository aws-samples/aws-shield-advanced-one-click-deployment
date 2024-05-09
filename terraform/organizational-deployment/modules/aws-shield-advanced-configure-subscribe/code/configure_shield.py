import botocore
import boto3
try:
  import cfnresponse
except:
  print ("no cfnresponse module")
import logging

logger = logging.getLogger('hc')
logger.setLevel('DEBUG')

shield_client = boto3.client('shield')

def lambda_handler(event, context):
    logger.debug(event)
    responseData = {}
    if "RequestType" in event:
        if event['RequestType'] in ['Create','Update']:
            try:
                logger.debug("Start Create Subscription")
                shield_client.create_subscription()
                logger.info ("Shield Enabled!")
                responseData['Message'] = "Subscription Created"
                #cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData, "SubscriptionCreated")
                return ()
            except botocore.exceptions.ClientError as error:
                if error.response['Error']['Code'] == 'ResourceAlreadyExistsException':
                    logger.info ("Subscription already active")
                    responseData['Message'] = "Already Subscribed to Shield Advanced"
                    #cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData, "AlreadySubscribedOk")
                    return
                else:
                    logger.error(error.response['Error'])
                    responseData['Message'] = error.response['Error']
                    #cfnresponse.send(event, context, cfnresponse.FAILED, responseData, "SubscribeFailed")
                    return ()
        else:
            responseData['Message'] = "CFN Delete, no action taken"
            #cfnresponse.send(event, context, cfnresponse.SUCCESS, responseData, "CFNDeleteGracefulContinue")
            return()