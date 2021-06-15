import json
import boto3

client = boto3.client('dynamodb', region_name='us-east-1')

def create_db():
    try:
        resp = client.create_table(
            TableName = "Board",
            # Primary key declaration
            KeySchema=[
            {
                "AttributeName": "x",
                "KeyType": "HASH"
            },
            {
                "AttributeName": "y",
                "KeyType": "RANGE"
            }
            ],
            AttributeDefinitions=[
            {
                "AttributeName": "x",
                "AttributeType": "N"
            },
            {
                "AttributeName": "y",
                "AttributeType": "N"
            }
            ],
            #because of free tier restrictions we have to limit this to 10, howver this can scale up to 20 million
            ProvisionedThroughput={
                "ReadCapacityUnits": 10,
                "WriteCapacityUnits": 10
            }
        )
        resp = client.create_table(
            TableName = "Users",
            # Primary key declaration
            KeySchema=[
            {
                "AttributeName": "Author",
                "KeyType": "HASH"
            }
            ],
            AttributeDefinitions=[
            {
                "AttributeName": "Author",
                "AttributeType": "S"
            }
            ],
            #because of free tier restrictions we have to limit this to 10, howver this can scale up to 20 million
            ProvisionedThroughput={
                "ReadCapacityUnits": 10,
                "WriteCapacityUnits": 10
            }
        )
        print("Tables created successfully!")
    except Exception as e:
        print("Error creating tables!")
        print(e)
    
if __name__ == "__main__":
    create_db()
