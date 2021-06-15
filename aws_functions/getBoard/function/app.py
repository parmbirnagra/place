from __future__ import print_function
import redis

redis = redis.Redis(host='redisplacecache.ocp81l.0001.use1.cache.amazonaws.com', port=6379, db=0)

def lambda_handler(event, context):
    try:
        # Get entire board state as a bytes string
        cache = redis.get("placeboard")
        board = []
    
        # Retrieve information for every tile
        for byte in cache:
            binary_repr = "{0:08b}".format(byte)
            board.append(int(binary_repr[0:4], 2))
            board.append(int(binary_repr[4:8], 2))
    
        return { 'statusCode': 200, 'body': board }
    except Exception as e:
        return { 'statusCode': 500, 'body': str(e) }