import json
import boto3

dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('Board')

def get_item(x,y):
    return table.get_item(Key={"x": x, "y": y})


def lambda_handler(event, context):
    
    res = get_item(event['x'], event['y'])
    if "Item" not in res:
            return {
                'statusCode':404,
                'body': json.dumps('Item not found!')
            }
    else:
        print(res['Item'])
        res['Item']['x'] = int(res['Item']['x'])
        res['Item']['y'] = int(res['Item']['y'])
        res['Item']['color'] = int(res['Item']['color'])
        res['Item']['time'] = int(res['Item']['time'])
        return {
            'statusCode': 200,
            'body': json.dumps(res['Item'])
        }
