from __future__ import print_function
import redis

redis = redis.Redis(host='redisplacecache.ocp81l.0001.use1.cache.amazonaws.com', port=6379, db=0)

def lambda_handler(event, context):
    try:
        offset = event["offset"]
        colour = event["colour"]
    
        # Set the specific tile at the specified offset to the specified colour
        operation = redis.bitfield("placeboard", default_overflow=None)
        operation.set("u4", 4*offset, colour)
        operation.execute()
        
        return { 'statusCode': 200 }
    
    except Exception as e:
        return { 'statusCode': 500, 'body': str(e) }