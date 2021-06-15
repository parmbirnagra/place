import json
import boto3
import time

dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table_board = dynamodb.Table('Board')
table_users = dynamodb.Table('Users')

def put_item(x,y,author,color):
    try:
        time_int = int(time.time())
        response = table_users.get_item(Key={'Author': author})
        if "Item" not in response: # user has not placed any pixels
            table_users.put_item(Item= {'Author': author, 'time': time_int})
            table_board.put_item(Item= {'x': x, 'y': y, 'time': time_int, 'author': author, 'color': color})
        elif( "Item" in response and response['Item']['time'] > time.time() - 300): #already did a place in the last 5 min
            return 2 #already placed in last 5 mins
        else:
            #update user's timestamp
            table_users.update_item(
                Key={'Author': author},
                UpdateExpression="set #ts = :t", 
                ExpressionAttributeValues={':t': time_int},
                ExpressionAttributeNames={"#ts": "time"},
                ReturnValues="UPDATED_NEW"
            )
            table_board.put_item(Item= {'x': x, 'y': y, 'time': time_int, 'author': author, 'color': color})
            
    except Exception as e:
        print("Error inserting value:")
        print(e)
        return -1
    return 1 # success

def lambda_handler(event, context):
    
    try:
        res = put_item(event['x'], event['y'], event['author'], event['color'])
        if res == 1:
            return {
                'statusCode': 200,
                'body': json.dumps('Inserted item!')
            }
        elif res == 2:
            return {
                'statusCode': 403,
                'body': json.dumps('Already placed in the last 5 mins!')
            }
        else:
            return {
                'statusCode': 500,
                'body': json.dumps('Error, check lambda logs!')
            }
    except Exception as e:
        print("Error inserting value:")
        print(e)
        return {
                'statusCode': 500,
                'body': json.dumps('Error, check lambda logs!')
            }
