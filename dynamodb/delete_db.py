import json
import boto3
client = boto3.client('dynamodb', region_name='us-east-1')

def delete_db():
    try:
        client.delete_table(TableName="Board",)
        client.delete_table(TableName="Users",)
        print("Tables deleted successfully!")
    except Exception as e:
        print("Error deleting tables!")
        print(e)

if __name__ == "__main__":
    delete_db()
