from __future__ import print_function
import redis

redis = redis.Redis(host='redisplacecache.ocp81l.0001.use1.cache.amazonaws.com', port=6379, db=0)

def lambda_handler(event, context):
    try:
        # Reinitialize the board state by deleting the old board
        redis.delete("placeboard")
        redis.setbit("placeboard", 1000*1000*4 - 1, 0)

        return { 'statusCode': 200 }
        
    except Exception as e:
        return { 'statusCode': 500, 'body': str(e) }