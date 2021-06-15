#!/bin/bash

# Change this line to the parent directory of your .aws
AWS_PAR_DIR="/Users/parmbirnagra/"

# SUBNETS
SUBNET_GROUP_NAME="place-subnet"
SUBNET_GROUP_DESC="place-group"

# LAMBDA ROLE
LAMBDA_ROLE="lambda-vpc-role"

# FUNCTIONS
REINTIALIZE_FUNC_NAME="reinitializeBoard"
PUT_ITEM_FILE_NAME="put_item"
GET_ITEM_FILE_NAME="get_item"
PUT_ITEM_NAME="putItem"
GET_ITEM_NAME="getItem"
MODIFY_TILE_NAME="modifyTile"
GET_BOARD_NAME="getBoard"

# DIRECTORIES
FUNCTION_DIR="aws_functions"
DB_DIR="dynamodb"
DATA_DIR="data"

FUNCTION_ZIP="function.zip"
IMAGE_ID="ami-00ddb0e5626798373"
KEY_NAME="place"

EC2_SERVER_FILE_NAME="ec2_server"
EC2_SECURITY_GROUP="ec2-place"
LAMBDA_SECURITY_GROUP="lambda-place"
REDIS_NAME="redisPlaceCache"

# DATA FILES
NULL="$DATA_DIR/null.txt"
EC2_1_JSON="$DATA_DIR/ec2_1.json"
EC2_1_STATUS_JSON="$DATA_DIR/ec2_1_status.json"
EC2_1_PUBLIC_DNS_JSON="$DATA_DIR/ec2_1_public_dns.json"

EC2_2_JSON="$DATA_DIR/ec2_2.json"
EC2_2_STATUS_JSON="$DATA_DIR/ec2_2_status.json"
EC2_2_PUBLIC_DNS_JSON="$DATA_DIR/ec2_2_public_dns.json"

TERMINATED_JSON="$DATA_DIR/terminated_instances.json"
DELETED_CACHE_JSON="$DATA_DIR/deleted_redis_msg.json"
SUBNET_JSON="$DATA_DIR/subnets.json"
SUBNET_FILE="$DATA_DIR/subnet_ids.txt"
LAMBDA_ROLE_JSON="$DATA_DIR/$LAMBDA_ROLE.json"
LAMBDA_SECURITY_GROUP_JSON="$DATA_DIR/$LAMBDA_SECURITY_GROUP.json"
EC2_SECURITY_GROUP_JSON="$DATA_DIR/$EC2_SECURITY_GROUP.json"
SUBNET_GROUP_JSON="$DATA_DIR/$SUBNET_GROUP_NAME.json"
REDIS_JSON="$DATA_DIR/$REDIS_NAME.json"

REINTIALIZE_JSON="$DATA_DIR/$REINTIALIZE_FUNC_NAME.json"
MODIFY_TILE_JSON="$DATA_DIR/$MODIFY_TILE_NAME.json"
GET_BOARD_JSON="$DATA_DIR/$GET_BOARD_NAME.json"
PUT_ITEM_JSON="$DATA_DIR/$PUT_ITEM_NAME.json"
GET_ITEM_JSON="$DATA_DIR/$GET_ITEM_NAME.json"
KEY_NAME_JSON="$DATA_DIR/$KEY_NAME.json"
KEY_NAME_PEM="$KEY_NAME.pem"
AWS_ZIP="aws-config.zip"
EC2_SERVER_ZIP="$EC2_SERVER_FILE_NAME.zip"
REPONSE_JSON="$DATA_DIR/response.json"

USAGE_FILE="usage.txt"
USAGE="$(cat $USAGE_FILE)"
CWD="$(pwd)"

mkdir -p $DATA_DIR
remove_null() {
  rm -f $NULL
}

create_role() {
  aws iam get-role \
    --role-name $LAMBDA_ROLE >$LAMBDA_ROLE_JSON
  if [ -s $LAMBDA_ROLE_JSON ]; then
    echo "$LAMBDA_ROLE already exists"
  else
    aws iam create-role \
      --role-name $LAMBDA_ROLE \
      --assume-role-policy-document \
      '{"Version": "2012-10-17",
    "Statement": [{ "Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]}' \
      >$LAMBDA_ROLE_JSON
    echo "Created role: $LAMBDA_ROLE"

    aws iam attach-role-policy \
      --role-name $LAMBDA_ROLE \
      --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole >$NULL
    echo "Attached role policy AWSLambdaVPCAccessExecutionRole to $LAMBDA_ROLE"

    aws iam attach-role-policy \
      --role-name $LAMBDA_ROLE \
      --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole >$NULL
    echo "Attached role policy AWSLambdaBasicExecutionRole to $LAMBDA_ROLE"

    aws iam attach-role-policy \
      --role-name $LAMBDA_ROLE \
      --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess >$NULL
    echo "Attached role policy AmazonDynamoDBFullAccess to $LAMBDA_ROLE"
    remove_null
  fi
}

delete_role() {
  aws iam get-role \
    --role-name $LAMBDA_ROLE >$LAMBDA_ROLE_JSON
  if [ -s $LAMBDA_ROLE_JSON ]; then
    aws iam detach-role-policy \
      --role-name $LAMBDA_ROLE \
      --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole >$NULL
    echo "Detached role policy AWSLambdaVPCAccessExecutionRole from $LAMBDA_ROLE"

    aws iam detach-role-policy \
      --role-name $LAMBDA_ROLE \
      --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole >$NULL
    echo "Detached role policy AWSLambdaBasicExecutionRole from $LAMBDA_ROLE"

    aws iam detach-role-policy \
      --role-name $LAMBDA_ROLE \
      --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess >$NULL
    echo "Detached role policy AmazonDynamoDBFullAccess from $LAMBDA_ROLE"

    aws iam delete-role \
      --role-name $LAMBDA_ROLE >$NULL
    echo "Deleted role: $LAMBDA_ROLE"
    rm -f $LAMBDA_ROLE_JSON
    remove_null
  else
    echo "$LAMBDA_ROLE already deleted"
    rm -f $LAMBDA_ROLE_JSON
  fi

}

create_security_groups() {
  aws ec2 describe-security-groups \
    --group-names $LAMBDA_SECURITY_GROUP >$LAMBDA_SECURITY_GROUP_JSON
  if [ -s $LAMBDA_SECURITY_GROUP_JSON ]; then
    echo "$LAMBDA_SECURITY_GROUP already exits"
  else
    aws ec2 create-security-group \
      --group-name $LAMBDA_SECURITY_GROUP \
      --description "$LAMBDA_SECURITY_GROUP for place CSC409" >$LAMBDA_SECURITY_GROUP_JSON

    LAMBDA_SECURITY_GROUP_ID="$(python3 -c "import sys, json; print(json.load(sys.stdin)['GroupId'])" \
      <$LAMBDA_SECURITY_GROUP_JSON)"
    echo "Created security group: $LAMBDA_SECURITY_GROUP"

    aws ec2 authorize-security-group-ingress \
      --group-id $LAMBDA_SECURITY_GROUP_ID \
      --protocol tcp \
      --port 6379 \
      --cidr 0.0.0.0/0 >$NULL

    aws ec2 authorize-security-group-ingress \
      --group-id $LAMBDA_SECURITY_GROUP_ID \
      --ip-permissions IpProtocol=tcp,FromPort=6379,ToPort=6379,Ipv6Ranges='[{CidrIpv6=::/0}]' >$NULL
  fi

  aws ec2 describe-security-groups \
    --group-names $EC2_SECURITY_GROUP >$EC2_SECURITY_GROUP_JSON
  if [ -s $EC2_SECURITY_GROUP_JSON ]; then
    echo "$EC2_SECURITY_GROUP already exits"
  else
    aws ec2 create-security-group \
      --group-name $EC2_SECURITY_GROUP \
      --description "$EC2_SECURITY_GROUP for place CSC409" >$EC2_SECURITY_GROUP_JSON

    echo "Created inbound rule for port 6379 for $LAMBDA_SECURITY_GROUP"

    EC2_SECURITY_GROUP_ID="$(python3 -c "import sys, json; print(json.load(sys.stdin)['GroupId'])" \
      <$EC2_SECURITY_GROUP_JSON)"
    echo "Created security group: $EC2_SECURITY_GROUP"

    for p in 8080 8081 443 22 9418 6379; do
      aws ec2 authorize-security-group-ingress \
        --group-id $EC2_SECURITY_GROUP_ID \
        --protocol tcp \
        --port $p \
        --cidr 0.0.0.0/0 >$NULL
      aws ec2 authorize-security-group-ingress \
        --group-id $EC2_SECURITY_GROUP_ID \
        --ip-permissions IpProtocol=tcp,FromPort=$p,ToPort=$p,Ipv6Ranges='[{CidrIpv6=::/0}]' >$NULL
      echo "Created inbound rule for port $p for $EC2_SECURITY_GROUP"
    done
  fi
  remove_null
}

delete_security_groups() {
  aws ec2 describe-security-groups \
    --group-names $LAMBDA_SECURITY_GROUP >$LAMBDA_SECURITY_GROUP_JSON

  if [ -s $LAMBDA_SECURITY_GROUP_JSON ]; then
    aws ec2 delete-security-group --group-name $LAMBDA_SECURITY_GROUP >$NULL
    echo "Deleted security group: $LAMBDA_SECURITY_GROUP"
    rm -f $LAMBDA_SECURITY_GROUP_JSON
  else
    echo "$LAMBDA_SECURITY_GROUP already deleted"
  fi

  aws ec2 describe-security-groups \
    --group-names $EC2_SECURITY_GROUP >$EC2_SECURITY_GROUP_JSON

  if [ -s $EC2_SECURITY_GROUP_JSON ]; then
    aws ec2 delete-security-group --group-name $EC2_SECURITY_GROUP >$NULL
    echo "Deleted security group: $EC2_SECURITY_GROUP"
    rm -f $EC2_SECURITY_GROUP_JSON
  else
    echo "$EC2_SECURITY_GROUP already deleted"
  fi
  remove_null
}

get_subnets() {
  aws ec2 describe-subnets >$SUBNET_JSON
  rm -f $SUBNET_FILE
  python3 -c "import sys, json; print(json.load(sys.stdin)['Subnets'][0]['SubnetId'])" <$SUBNET_JSON >>$SUBNET_FILE
  python3 -c "import sys, json; print(json.load(sys.stdin)['Subnets'][1]['SubnetId'])" <$SUBNET_JSON >>$SUBNET_FILE
  python3 -c "import sys, json; print(json.load(sys.stdin)['Subnets'][2]['SubnetId'])" <$SUBNET_JSON >>$SUBNET_FILE
  rm -f $SUBNET_JSON
  echo "Created $SUBNET_FILE"
}

create_cache() {
  get_subnets
  SUBNET_ID1="$(sed '1q;d' $SUBNET_FILE)"
  SUBNET_ID2="$(sed '2q;d' $SUBNET_FILE)"
  rm -f $SUBNET_FILE

  aws ec2 describe-security-groups \
    --group-names $LAMBDA_SECURITY_GROUP >$LAMBDA_SECURITY_GROUP_JSON
  if [ -s $LAMBDA_SECURITY_GROUP_JSON ]; then
    LAMBDA_SECURITY_GROUP_ID="$(python3 -c \
      "import sys, json; print(json.load(sys.stdin)['SecurityGroups'][0]['GroupId'])" \
      <$LAMBDA_SECURITY_GROUP_JSON)"

    aws elasticache describe-cache-subnet-groups \
      --cache-subnet-group-name $SUBNET_GROUP_NAME >$SUBNET_GROUP_JSON

    if [ -s $SUBNET_GROUP_JSON ]; then
      echo "elasticache cache subnet group $SUBNET_GROUP_NAME is already created"
    else
      aws elasticache create-cache-subnet-group \
        --cache-subnet-group-name $SUBNET_GROUP_NAME \
        --cache-subnet-group-description $SUBNET_GROUP_DESC \
        --subnet-ids $SUBNET_ID1 $SUBNET_ID2 >$SUBNET_GROUP_JSON
      echo "Created cache subnet group: $SUBNET_GROUP_NAME with Subnets: $SUBNET_ID1, $SUBNET_ID2"
    fi

    aws elasticache describe-cache-clusters \
      --cache-cluster-id $REDIS_NAME >$REDIS_JSON

    if [ -s $REDIS_JSON ]; then
      echo "elasticache cache cluster $REDIS_NAME is already created"
    else
      echo "creating cache..."
      aws elasticache create-cache-cluster \
        --cache-cluster-id $REDIS_NAME \
        --cache-node-type cache.t2.micro \
        --engine redis \
        --num-cache-nodes 1 \
        --security-group-ids $LAMBDA_SECURITY_GROUP_ID \
        --cache-subnet-group-name $SUBNET_GROUP_NAME >$REDIS_JSON
      echo "Created elasticache cache cluster: $REDIS_NAME with Subnet group: $SUBNET_GROUP_NAME"
    fi
  else
    echo "$LAMBDA_SECURITY_GROUP needs to be created"
  fi
}

delete_cache_cluster() {
  aws elasticache describe-cache-clusters \
    --cache-cluster-id $REDIS_NAME >$REDIS_JSON

  if [ -s $REDIS_JSON ]; then
    REDIS_STATUS="$(python3 -c \
      "import sys, json; print(json.load(sys.stdin)['CacheClusters'][0]['CacheClusterStatus'])" \
      <$REDIS_JSON)"
    if [ "$REDIS_STATUS" == "available" ]; then
      aws elasticache delete-cache-cluster --cache-cluster-id $REDIS_NAME >$REDIS_JSON
      echo "Deleted elasticache cache cluster: $REDIS_NAME"
      echo "Wait for $REDIS_NAME to fully terminate before deleting the subnet group: $SUBNET_GROUP_NAME"
    else
      if [ "$REDIS_STATUS" == "deleting" ]; then
        echo "$REDIS_NAME is already being deleted"
      else
        echo "$REDIS_NAME cannot be deleted now"
      fi
    fi
  else
    echo "elasticache $REDIS_NAME is not created"
    rm -f $REDIS_JSON
  fi
}

get_cache_cluster_status() {
  aws elasticache describe-cache-clusters
}

delete_cache_subnet_group() {
  aws elasticache describe-cache-clusters \
    --cache-cluster-id $REDIS_NAME >$REDIS_JSON

  if [ ! -s $REDIS_JSON ]; then
    aws elasticache delete-cache-subnet-group --cache-subnet-group-name $SUBNET_GROUP_NAME >$NULL
    echo "Deleted cache subnet group: $SUBNET_GROUP_NAME"
    rm -f $DELETED_CACHE_JSON
    rm -f $SUBNET_GROUP_JSON
    remove_null
  else
    echo "$REDIS_NAME has to be fully deleted"
  fi
  rm -f $REDIS_JSON
}

add_cache_endpoints() {
  aws elasticache describe-cache-clusters \
    --cache-cluster-id $REDIS_NAME \
    --show-cache-node-info >$REDIS_JSON

  ELASTICACHE=$(python3 -c \
    "import sys, json; print(json.load(sys.stdin)['CacheClusters'][0]['CacheNodes'][0]['Endpoint']['Address'])" \
    <$REDIS_JSON)
  for f in $REINTIALIZE_FUNC_NAME $MODIFY_TILE_NAME $GET_BOARD_NAME; do
    sed -e "4s/.*/redis = redis.Redis(host='$ELASTICACHE', port=6379, db=0)/" \
      -i "" $FUNCTION_DIR/$f/function/app.py
    echo "Edited $FUNCTION_DIR/$f/function/app.py"
    cd $FUNCTION_DIR/$f/function/ && zip -r $FUNCTION_ZIP app.py redis redis-3.5.3.dist-info && cd ../../../
    mv $FUNCTION_DIR/$f/function/$FUNCTION_ZIP $FUNCTION_DIR/$f/
    echo "Created $FUNCTION_DIR/$f/$FUNCTION_ZIP"
  done
  cd "$CWD"
  sed -e \
    "13s/.*/var redis_client_pub = require('redis').createClient(6379, '$ELASTICACHE', {no_ready_check: true});/" \
    -i "" server.js
  sed -e \
    "14s/.*/var redis_client_sub = require('redis').createClient(6379, '$ELASTICACHE', {no_ready_check: true});/" \
    -i "" server.js
  echo "Edited server.js"
}

create_lambda_functions() {
  get_subnets
  SUBNET_ID1="$(sed '1q;d' $SUBNET_FILE)"
  SUBNET_ID2="$(sed '2q;d' $SUBNET_FILE)"
  rm -f $SUBNET_FILE

  aws ec2 describe-security-groups \
    --group-names $LAMBDA_SECURITY_GROUP >$LAMBDA_SECURITY_GROUP_JSON

  if [ -s $LAMBDA_SECURITY_GROUP_JSON ]; then
    LAMBDA_SECURITY_GROUP_ID="$(python3 -c \
      "import sys, json; print(json.load(sys.stdin)['SecurityGroups'][0]['GroupId'])" \
      <$LAMBDA_SECURITY_GROUP_JSON)"

    aws elasticache describe-cache-clusters \
      --cache-cluster-id $REDIS_NAME >$REDIS_JSON

    if [ -s $REDIS_JSON ]; then
      REDIS_STATUS="$(python3 -c \
        "import sys, json; print(json.load(sys.stdin)['CacheClusters'][0]['CacheClusterStatus'])" \
        <$REDIS_JSON)"
      if [ "$REDIS_STATUS" == "available" ]; then
        add_cache_endpoints

        aws iam get-role \
          --role-name $LAMBDA_ROLE >$LAMBDA_ROLE_JSON

        if [ -s $LAMBDA_ROLE_JSON ]; then
          LAMBDA_ROLE_ARN="$(python3 -c \
            "import sys, json; print(json.load(sys.stdin)['Role']['Arn'])" \
            <$LAMBDA_ROLE_JSON)"
          cd $FUNCTION_DIR/$REINTIALIZE_FUNC_NAME &&
            aws lambda create-function \
              --function-name $REINTIALIZE_FUNC_NAME \
              --timeout 15 \
              --memory-size 1024 \
              --zip-file fileb://$FUNCTION_ZIP \
              --handler app.lambda_handler \
              --runtime python3.8 \
              --role "$LAMBDA_ROLE_ARN" \
              --vpc-config SubnetIds="$SUBNET_ID1","$SUBNET_ID2",SecurityGroupIds="$LAMBDA_SECURITY_GROUP_ID" \
              >../../$REINTIALIZE_JSON && cd ../../
          echo "Created lambda function: $REINTIALIZE_FUNC_NAME"

          cd $FUNCTION_DIR/$MODIFY_TILE_NAME &&
            aws lambda create-function \
              --function-name $MODIFY_TILE_NAME \
              --timeout 15 \
              --memory-size 1024 \
              --zip-file fileb://$FUNCTION_ZIP \
              --handler app.lambda_handler \
              --runtime python3.8 \
              --role "$LAMBDA_ROLE_ARN" \
              --vpc-config SubnetIds="$SUBNET_ID1","$SUBNET_ID2",SecurityGroupIds="$LAMBDA_SECURITY_GROUP_ID" \
              >../../$MODIFY_TILE_JSON && cd ../../
          echo "Created lambda function: $MODIFY_TILE_NAME"

          cd $FUNCTION_DIR/$GET_BOARD_NAME &&
            aws lambda create-function \
              --function-name $GET_BOARD_NAME \
              --timeout 15 \
              --memory-size 1024 \
              --zip-file fileb://$FUNCTION_ZIP \
              --handler app.lambda_handler \
              --runtime python3.8 \
              --role "$LAMBDA_ROLE_ARN" \
              --vpc-config SubnetIds="$SUBNET_ID1","$SUBNET_ID2",SecurityGroupIds="$LAMBDA_SECURITY_GROUP_ID" \
              >../../$GET_BOARD_JSON && cd ../../
          echo "Created lambda function: $GET_BOARD_NAME"

          cd $FUNCTION_DIR/$PUT_ITEM_FILE_NAME &&
            aws lambda create-function \
              --function-name $PUT_ITEM_NAME \
              --timeout 15 \
              --memory-size 1024 \
              --zip-file fileb://$PUT_ITEM_FILE_NAME.zip \
              --handler lambda_function.lambda_handler \
              --runtime python3.8 \
              --role "$LAMBDA_ROLE_ARN" \
              >../../$PUT_ITEM_JSON && cd ../../
          echo "Created lambda function: $PUT_ITEM_NAME"

          cd $FUNCTION_DIR/$GET_ITEM_FILE_NAME &&
            aws lambda create-function \
              --function-name $GET_ITEM_NAME \
              --timeout 15 \
              --memory-size 1024 \
              --zip-file fileb://$GET_ITEM_FILE_NAME.zip \
              --handler lambda_function.lambda_handler \
              --runtime python3.8 \
              --role "$LAMBDA_ROLE_ARN" \
              >../../$GET_ITEM_JSON && cd ../../
          echo "Created lambda function: $GET_ITEM_NAME"

        else
          echo "$LAMBDA_ROLE is not created"
          rm -f $LAMBDA_ROLE_JSON
        fi
      else
        echo "Cannot create lambda functions now, wait for $REDIS_NAME"
      fi
    else
      echo "elasticache $REDIS_NAME is not created"
      rm -f $REDIS_JSON
    fi
  else
    echo "$LAMBDA_SECURITY_GROUP is not created"
  fi
}

delete_lambda_functions() {
  aws lambda delete-function --function-name $REINTIALIZE_FUNC_NAME >$NULL
  echo "Deleted lambda function: $REINTIALIZE_FUNC_NAME"
  rm -rf $REINTIALIZE_JSON

  aws lambda delete-function --function-name $MODIFY_TILE_NAME >$NULL
  echo "Deleted lambda function: $MODIFY_TILE_NAME"
  rm -rf $MODIFY_TILE_JSON

  aws lambda delete-function --function-name $GET_BOARD_NAME >$NULL
  echo "Deleted lambda function: $GET_BOARD_NAME"
  rm -rf $GET_BOARD_JSON

  aws lambda delete-function --function-name $PUT_ITEM_NAME >$NULL
  echo "Deleted lambda function: $PUT_ITEM_NAME"
  rm -rf $PUT_ITEM_JSON

  aws lambda delete-function --function-name $GET_ITEM_NAME >$NULL
  echo "Deleted lambda function: $GET_ITEM_NAME"
  rm -rf $GET_ITEM_JSON
  remove_null
}

get_lambda_function_status() {
  aws lambda list-functions
}

create_key_pair() {
  aws ec2 create-key-pair --key-name $KEY_NAME >$KEY_NAME_JSON
  echo "Created $KEY_NAME_JSON"

  python3 -c "import sys, json; print(json.load(sys.stdin)['KeyMaterial'])" <$KEY_NAME_JSON >$KEY_NAME_PEM
  echo "Created $KEY_NAME_PEM"
  rm -rf $KEY_NAME_JSON
  chmod 400 $KEY_NAME_PEM
}

delete_key_pair() {
  aws ec2 delete-key-pair --key-name $KEY_NAME >$NULL
  echo "Deleted key pair: $KEY_NAME"

  rm -f $KEY_NAME_PEM
  echo "Deleted key pair: $KEY_NAME_PEM"

  rm -f $KEY_NAME_JSON
  echo "Deleted key pair: $KEY_NAME_JSON"
}

create_ec2() {
  get_subnets
  SUBNET_ID1="$(sed '1q;d' $SUBNET_FILE)"
  SUBNET_ID2="$(sed '2q;d' $SUBNET_FILE)"
  rm -f $SUBNET_FILE

  aws ec2 describe-security-groups \
    --group-names $EC2_SECURITY_GROUP >$EC2_SECURITY_GROUP_JSON

  if [ -s $EC2_SECURITY_GROUP_JSON ]; then
    EC2_SECURITY_GROUP_ID="$(python3 -c \
      "import sys, json; print(json.load(sys.stdin)['SecurityGroups'][0]['GroupId'])" \
      <$EC2_SECURITY_GROUP_JSON)"

    aws ec2 run-instances \
      --image-id $IMAGE_ID \
      --count 1 \
      --instance-type t2.micro \
      --key-name $KEY_NAME \
      --security-group-ids "$EC2_SECURITY_GROUP_ID" \
      --subnet-id "$SUBNET_ID1" >$EC2_1_JSON

    INSTANCE_1_ID="$(python3 -c "import sys, json; print(json.load(sys.stdin)['Instances'][0]['InstanceId'])" \
      <$EC2_1_JSON)"
    echo "Create EC2 instance: $INSTANCE_1_ID"
    echo "See $EC2_1_JSON for details"

    aws ec2 run-instances \
      --image-id $IMAGE_ID \
      --count 1 \
      --instance-type t2.micro \
      --key-name $KEY_NAME \
      --security-group-ids "$EC2_SECURITY_GROUP_ID" \
      --subnet-id "$SUBNET_ID2" >$EC2_2_JSON

    INSTANCE_2_ID="$(python3 -c "import sys, json; print(json.load(sys.stdin)['Instances'][0]['InstanceId'])" \
      <$EC2_2_JSON)"
    echo "Create EC2 instance: $INSTANCE_2_ID"
    echo "See $EC2_2_JSON for details"
    aws ec2 monitor-instances --instance-ids $INSTANCE_1_ID $INSTANCE_2_ID >$NULL
  else
    echo "$EC2_SECURITY_GROUP is not created"
  fi
}

delete_ec2_1() {
  if [ -s "$EC2_1_JSON" ]; then
    INSTANCE_1_ID="$(python3 -c "import sys, json; print(json.load(sys.stdin)['Instances'][0]['InstanceId'])" \
      <$EC2_1_JSON)"
    aws ec2 describe-instances --instance-ids $INSTANCE_1_ID --query 'Reservations[].Instances[].State' \
      >$EC2_1_STATUS_JSON
    STATE1="$(python3 -c "import sys, json; print(json.load(sys.stdin)[0]['Name'])" \
      <$EC2_1_STATUS_JSON)"
    if [ "$STATE1" == "running" ]; then
      aws ec2 terminate-instances --instance-ids $INSTANCE_1_ID >$EC2_1_JSON
      echo "Terminated EC2 instance: $INSTANCE_1_ID"
      rm -f $EC2_1_JSON
      rm -f $EC2_1_STATUS_JSON
      rm -f $EC2_1_PUBLIC_DNS_JSON
      rm -rf $AWS_ZIP
      rm -rf $EC2_SERVER_ZIP
    else
      echo "$INSTANCE_1_ID cannot be deleted"
    fi
  else
    echo "$EC2_1_JSON not found"
  fi
}

delete_ec2_2() {
  if [ -s "$EC2_2_JSON" ]; then
    INSTANCE_2_ID="$(python3 -c "import sys, json; print(json.load(sys.stdin)['Instances'][0]['InstanceId'])" <$EC2_2_JSON)"
    aws ec2 describe-instances --instance-ids $INSTANCE_2_ID --query 'Reservations[].Instances[].State' >$EC2_2_STATUS_JSON
    STATE2="$(python3 -c "import sys, json; print(json.load(sys.stdin)[0]['Name'])" <$EC2_2_STATUS_JSON)"

    if [ "$STATE2" == "running" ]; then
      aws ec2 terminate-instances --instance-ids $INSTANCE_2_ID >$EC2_1_JSON
      echo "Terminated EC2 instance: $INSTANCE_2_ID"
      rm -f $EC2_2_JSON
      rm -f $EC2_2_STATUS_JSON
      rm -f $EC2_2_PUBLIC_DNS_JSON
      rm -rf $AWS_ZIP
      rm -rf $EC2_SERVER_ZIP
    else
      echo "$INSTANCE_2_ID cannot be deleted"
    fi
  else
    echo "$EC2_2_JSON not found"
  fi

}

delete_ec2_instances() {
  delete_ec2_1
  delete_ec2_2
}

zip_server_files() {
  zip -r $EC2_SERVER_ZIP package-lock.json package.json server.js node_modules static_files
  cd "$AWS_PAR_DIR" && zip -r "$AWS_ZIP" .aws
  mv "$AWS_PAR_DIR/$AWS_ZIP" "$CWD"
  cd "$CWD"
}

ssh_ec2_1() {
  if [ -s "$EC2_1_JSON" ]; then
    INSTANCE_1_ID="$(python3 -c "import sys, json; print(json.load(sys.stdin)['Instances'][0]['InstanceId'])" <$EC2_1_JSON)"
    aws ec2 describe-instances --instance-ids $INSTANCE_1_ID --query 'Reservations[].Instances[].State' >$EC2_1_STATUS_JSON
    STATE1="$(python3 -c "import sys, json; print(json.load(sys.stdin)[0]['Name'])" <$EC2_1_STATUS_JSON)"

    if [ "$STATE1" == "running" ]; then
      aws ec2 describe-instances --instance-ids $INSTANCE_1_ID --query 'Reservations[].Instances[].PublicDnsName' \
        >$EC2_1_PUBLIC_DNS_JSON
      PUBLIC_1_DNS="$(python3 -c "import sys, json; print(json.load(sys.stdin)[0])" \
        <$EC2_1_PUBLIC_DNS_JSON)"

      if [ -s "$KEY_NAME_PEM" ]; then
        scp -i "$KEY_NAME_PEM" $AWS_ZIP ubuntu@$PUBLIC_1_DNS:~/.
        scp -i "$KEY_NAME_PEM" $EC2_SERVER_ZIP ubuntu@$PUBLIC_1_DNS:~/.
        ssh -i "$KEY_NAME_PEM" ubuntu@$PUBLIC_1_DNS <<HERE
curl -sL https://deb.nodesource.com/setup_current.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo apt-get install -y unzip
sudo apt-get install -y awscli
rm -rf .aws
rm -rf server
unzip aws-config.zip
unzip ec2_server.zip -d server
cd server
pkill node
nohup node --max-old-space-size=512 --nouse-idle-notification server.js > /dev/null 2>&1 &
echo go to $PUBLIC_1_DNS:8080
HERE
      else
        echo "there is no key pair $KEY_NAME"
      fi
    else
      echo "Wait for $INSTANCE_1_ID to start"
    fi
  else
    echo "$EC2_1_JSON not found"
  fi
}

ssh_ec2_2() {
  if [ -s "$EC2_2_JSON" ]; then
    INSTANCE_2_ID="$(python3 -c "import sys, json; print(json.load(sys.stdin)['Instances'][0]['InstanceId'])" <$EC2_2_JSON)"
    aws ec2 describe-instances --instance-ids $INSTANCE_2_ID --query 'Reservations[].Instances[].State' >$EC2_2_STATUS_JSON
    STATE2="$(python3 -c "import sys, json; print(json.load(sys.stdin)[0]['Name'])" <$EC2_2_STATUS_JSON)"

    if [ "$STATE2" == "running" ]; then
      aws ec2 describe-instances --instance-ids $INSTANCE_2_ID --query 'Reservations[].Instances[].PublicDnsName' \
        >$EC2_2_PUBLIC_DNS_JSON
      PUBLIC_2_DNS="$(python3 -c "import sys, json; print(json.load(sys.stdin)[0])" \
        <$EC2_2_PUBLIC_DNS_JSON)"

      if [ -s "$KEY_NAME_PEM" ]; then
        scp -i "$KEY_NAME_PEM" $AWS_ZIP ubuntu@$PUBLIC_2_DNS:~/.
        scp -i "$KEY_NAME_PEM" $EC2_SERVER_ZIP ubuntu@$PUBLIC_2_DNS:~/.
        ssh -i "$KEY_NAME_PEM" ubuntu@$PUBLIC_2_DNS <<HERE
curl -sL https://deb.nodesource.com/setup_current.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo apt-get install -y unzip
sudo apt-get install -y awscli
rm -rf .aws
rm -rf server
unzip aws-config.zip
unzip ec2_server.zip -d server
cd server
pkill node
nohup node --max-old-space-size=512 --nouse-idle-notification server.js > /dev/null 2>&1 &
echo go to $PUBLIC_2_DNS:8080
HERE
      else
        echo "there is no key pair $KEY_NAME"
      fi
    else
      echo "Wait for $INSTANCE_2_ID to start"
    fi
  else
    echo "$EC2_2_JSON not found"
  fi
}

start_ec2() {
  aws elasticache describe-cache-clusters \
    --cache-cluster-id $REDIS_NAME >$REDIS_JSON

  if [ -s $REDIS_JSON ]; then
    REDIS_STATUS="$(python3 -c \
      "import sys, json; print(json.load(sys.stdin)['CacheClusters'][0]['CacheClusterStatus'])" <$REDIS_JSON)"
    if [ "$REDIS_STATUS" == "available" ]; then
      add_cache_endpoints

      aws lambda invoke --function-name $GET_BOARD_NAME output.json >$REPONSE_JSON
      STATUS="$(python3 -c "import sys, json; print(json.load(sys.stdin)['StatusCode'])" <$REPONSE_JSON)"
      if [ $STATUS -eq 500 ]; then
	echo "$STATUS found"
        aws lambda invoke --function-name $REINTIALIZE_FUNC_NAME output.json >$REPONSE_JSON
        zip_server_files
        ssh_ec2_1
        ssh_ec2_2
      else
        zip_server_files
        ssh_ec2_1
        ssh_ec2_2
      fi
    fi
  else
    echo "elasticache $REDIS_NAME is not created"
    rm -f $REDIS_JSON
  fi
  rm -f $REPONSE_JSON
}

ssh_kill_ec2_1() {
  if [ -s "$EC2_1_JSON" ]; then
    INSTANCE_1_ID="$(python3 -c "import sys, json; print(json.load(sys.stdin)['Instances'][0]['InstanceId'])" <$EC2_1_JSON)"
    aws ec2 describe-instances --instance-ids $INSTANCE_1_ID --query 'Reservations[].Instances[].State' >$EC2_1_STATUS_JSON
    STATE2="$(python3 -c "import sys, json; print(json.load(sys.stdin)[0]['Name'])" <$EC2_1_STATUS_JSON)"

    if [ "$STATE2" == "running" ]; then
      aws ec2 describe-instances --instance-ids $INSTANCE_1_ID --query 'Reservations[].Instances[].PublicDnsName' >$EC2_1_PUBLIC_DNS_JSON
      PUBLIC_1_DNS="$(python3 -c "import sys, json; print(json.load(sys.stdin)[0])" <$EC2_1_PUBLIC_DNS_JSON)"
      if [ -s "$KEY_NAME_PEM" ]; then
        ssh -i "$KEY_NAME_PEM" ubuntu@$PUBLIC_1_DNS <<HERE
pkill node
HERE
        echo "killed node server for $INSTANCE_1_ID"
      else
        echo "there is no key pair $KEY_NAME"
      fi
    else
      echo "Wait for $INSTANCE_1_ID to start"
    fi
  else
    echo "$EC2_1_JSON not found"
  fi
}

ssh_kill_ec2_2() {
  if [ -s "$EC2_2_JSON" ]; then
    INSTANCE_2_ID="$(python3 -c "import sys, json; print(json.load(sys.stdin)['Instances'][0]['InstanceId'])" <$EC2_2_JSON)"
    aws ec2 describe-instances --instance-ids $INSTANCE_2_ID --query 'Reservations[].Instances[].State' >$EC2_2_STATUS_JSON
    STATE2="$(python3 -c "import sys, json; print(json.load(sys.stdin)[0]['Name'])" <$EC2_2_STATUS_JSON)"

    if [ "$STATE2" == "running" ]; then
      aws ec2 describe-instances --instance-ids $INSTANCE_2_ID --query 'Reservations[].Instances[].PublicDnsName' >$EC2_2_PUBLIC_DNS_JSON
      PUBLIC_2_DNS="$(python3 -c "import sys, json; print(json.load(sys.stdin)[0])" <$EC2_2_PUBLIC_DNS_JSON)"
      if [ -s "$KEY_NAME_PEM" ]; then
        ssh -i "$KEY_NAME_PEM" ubuntu@$PUBLIC_2_DNS <<HERE
pkill node
HERE
        echo "killed node server for $INSTANCE_2_ID"
      else
        echo "there is no key pair $KEY_NAME"
      fi
    else
      echo "Wait for $INSTANCE_2_ID to start"
    fi
  else
    echo "$EC2_2_JSON not found"
  fi
}

ssh_kill_ec2() {
  ssh_kill_ec2_1
  ssh_kill_ec2_2
  rm -rf $AWS_ZIP
  rm -rf $EC2_SERVER_ZIP
}

create_db() {
  python3 $DB_DIR/create_db.py
}

delete_db() {
  python3 $DB_DIR/delete_db.py
}

get_ec2_status() {
  if [ -s "$EC2_1_JSON" ]; then
    INSTANCE_1_ID="$(python3 -c "import sys, json; print(json.load(sys.stdin)['Instances'][0]['InstanceId'])" \
      <$EC2_1_JSON)"
    aws ec2 describe-instances --instance-ids $INSTANCE_1_ID --query 'Reservations[].Instances[].State' \
      >$EC2_1_STATUS_JSON
    STATE1="$(python3 -c "import sys, json; print(json.load(sys.stdin)[0]['Name'])" \
      <$EC2_1_STATUS_JSON)"
    echo "$INSTANCE_1_ID: $STATE1"
  fi

  if [ -s "$EC2_1_JSON" ]; then
    INSTANCE_2_ID="$(python3 -c "import sys, json; print(json.load(sys.stdin)['Instances'][0]['InstanceId'])" \
      <$EC2_2_JSON)"
    aws ec2 describe-instances --instance-ids $INSTANCE_2_ID --query 'Reservations[].Instances[].State' \
      >$EC2_2_STATUS_JSON
    STATE2="$(python3 -c "import sys, json; print(json.load(sys.stdin)[0]['Name'])" \
      <$EC2_2_STATUS_JSON)"
    echo "$INSTANCE_2_ID: $STATE2"
  fi
}

if [ "$1" = "-c" ] || [ "$1" = "--create" ]; then
  if [ "$2" = "ro" ]; then
    create_role
  else
    if [ "$2" = "sg" ]; then
      create_security_groups
    else
      if [ "$2" = "cc" ]; then
        create_cache
      else
        if [ "$2" = "db" ]; then
          create_db
        else
          if [ "$2" = "lf" ]; then
            create_lambda_functions
          else
            if [ "$2" = "kp" ]; then
              create_key_pair
            else
              if [ "$2" = "e2" ]; then
                create_ec2
              else
                echo "$USAGE"
              fi
            fi
          fi
        fi
      fi
    fi
  fi
else
  if [ "$1" = "-d" ] || [ "$1" = "--delete" ]; then
    if [ "$2" = "ro" ]; then
      delete_role
    else
      if [ "$2" = "sg" ]; then
        delete_security_groups
      else
        if [ "$2" = "cc" ]; then
          delete_cache_cluster
        else
          if [ "$2" = "cg" ]; then
            delete_cache_subnet_group
          else
            if [ "$2" = "db" ]; then
              delete_db
            else
              if [ "$2" = "lf" ]; then
                delete_lambda_functions
              else
                if [ "$2" = "kp" ]; then
                  delete_key_pair
                else
                  if [ "$2" = "1" ]; then
                    delete_ec2_1
                  else
                    if [ "$2" = "2" ]; then
                      delete_ec2_2
                    else
                      if [ "$2" = "e2" ]; then
                        delete_ec2_instances
                      else
                        echo "$USAGE"
                      fi
                    fi
                  fi
                fi
              fi
            fi
          fi
        fi
      fi
    fi
  else
    if [ "$1" = "-t" ] || [ "$1" = "--status" ]; then
      if [ "$2" = "cc" ]; then
        get_cache_cluster_status
      else
        if [ "$2" = "lf" ]; then
          get_lambda_function_status
        else
          if [ "$2" = "e2" ]; then
            get_ec2_status
          else
            echo "$USAGE"
          fi
        fi
      fi
    else
      if [ "$1" = "-s" ] || [ "$1" = "--start" ]; then
        if [ "$2" = "e2" ]; then
          start_ec2
        else
          echo "$USAGE"
        fi
      else
        if [ "$1" = "-k" ] || [ "$1" = "--kill" ]; then
          if [ "$2" = "1" ]; then
            ssh_kill_ec2_1
          else
            if [ "$2" = "2" ]; then
              ssh_kill_ec2_2
            else
              if [ "$2" = "e2" ]; then
                ssh_kill_ec2
              else
                echo "$USAGE"
              fi
            fi
          fi
        else
          echo "$USAGE"
        fi
      fi
    fi
  fi
fi

remove_null
