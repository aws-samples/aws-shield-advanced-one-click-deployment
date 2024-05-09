import boto3
import datetime
import os
import time
import json
import urllib3
import botocore
s3BasePath = os.environ['s3BasePath']
workGroupName = os.environ['workGroupName']
database = os.environ['glueDatabase']
athena_client = boto3.client('athena')
http = urllib3.PoolManager()
responseData = {}
def cfnrespond(event, context, responseStatus, responseData, physicalResourceId=None, noEcho=False):
    responseUrl = event['ResponseURL']
    responseBody = {}
    responseBody['Status'] = responseStatus
    responseBody['Reason'] = 'See the details in CloudWatch Log Stream: ' + context.log_stream_name
    responseBody['PhysicalResourceId'] = physicalResourceId or context.log_stream_name
    responseBody['StackId'] = event['StackId']
    responseBody['RequestId'] = event['RequestId']
    responseBody['LogicalResourceId'] = event['LogicalResourceId']
    responseBody['NoEcho'] = noEcho
    responseBody['Data'] = responseData
    json_responseBody = json.dumps(responseBody)
    print("Response body:\n" + json_responseBody)
    headers = {
      'content-type' : '',
      'content-length' : str(len(json_responseBody))
    }
    try:
        response = http.request('PUT',responseUrl,body=json_responseBody.encode('utf-8'),headers=headers)
        print("Status code: " + response.reason)
    except Exception as e:
        print("send(..) failed executing requests.put(..): " + str(e))
def wait_for_queries_to_finish(executionIdList):
  while (executionIdList != []):
    for eId in executionIdList:
      currentState = athena_client.get_query_execution(QueryExecutionId=eId)['QueryExecution']['Status']['State']
      if currentState in ['SUCCEEDED']:
        executionIdList.remove (eId)
      elif currentState in ['FAILED','CANCELLED']:
        return (executionIdList)
    time.sleep(1)
  return ([])
def lambda_handler(event, context):
  print (json.dumps(event))
  # if event['RequestType'] == 'Delete':
  #   try:
  #     athena_client.delete_work_group(
  #         WorkGroup=workGroupName,
  #         RecursiveDeleteOption=True
  #       )
  #     cfnrespond(event, context, "SUCCESS", {}, "Graceful Delete")
  #     return ()
  #   except:
  #     cfnrespond(event, context, "FAILED", {}, "")
  #     return ()
  # else:
  executionIdList = []
  transformQuery = False
  transformQuery = True
  detailedViewQueryId = event['DetailedViewQueryId']
  # detailedViewQueryId = event['ResourceProperties']['DetailedViewQueryId']
  baseQueryString = athena_client.get_named_query(
    NamedQueryId=detailedViewQueryId)['NamedQuery']['QueryString']
  queryString = "CREATE OR REPLACE VIEW waf_detailed AS " + baseQueryString
  try:
    r = athena_client.start_query_execution(
          QueryString=queryString,
          QueryExecutionContext={
            'Database': database,
            'Catalog': 'AwsDataCatalog'},
          WorkGroup=workGroupName
      )
  except botocore.exceptions.ClientError as error:
    print (error.response)
    # cfnrespond(event, context, "FAILED", {}, "")
    return ()
  #Wait for query to finish, it should take a second but wait just in case
  if wait_for_queries_to_finish([r['QueryExecutionId']]) != []:
    # cfnrespond(event, context, "FAILED", responseData, "CreateViewQueriesFailed")
    return ("QueriesFailed")
  #Get all named query IDs in WorkGroup
  namedQueries = athena_client.list_named_queries(
    WorkGroup=workGroupName)['NamedQueryIds']
  #Get all Named Queries
  for queryId in namedQueries:
    queryResults = athena_client.get_named_query(
          NamedQueryId=queryId
      )['NamedQuery']
    print (queryResults)
    if queryResults['Name'] != 'waf_detailed':
      outputLocation = s3BasePath + queryResults['Name'].split('-')[-1] + '/'
      if transformQuery:
        queryString = "CREATE OR REPLACE VIEW " + '"' + database + '".' + queryResults['Name'].replace('-','_') + " AS " + queryResults['QueryString']
      else:
        queryString = queryResults['QueryString']
      print ("queryString")
      print (queryString)
      try:
        r = athena_client.start_query_execution(
            QueryString=queryString,
            ResultConfiguration={
                'OutputLocation': outputLocation,
                'EncryptionConfiguration': {
                    'EncryptionOption': 'SSE_S3',
                }
            },
            WorkGroup=workGroupName
        )
        executionIdList.append(r['QueryExecutionId'])
      except botocore.exceptions.ClientError as error:
        print (error.response)
        # cfnrespond(event, context, "FAILED", {}, "")
        return ()
    print (executionIdList)
    if wait_for_queries_to_finish(executionIdList) != []:
      # cfnrespond(event, context, "FAILED", responseData, "CreateViewQueriesFailed")
      return ("QueriesFailed")
    else:
      return ("QueriesSuccess")
      # cfnrespond(event, context, "SUCCESS", responseData, "CreateViewsSuccessful")