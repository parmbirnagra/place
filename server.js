const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8081 });

// Retrieve AWS credentials and confi
const AWS = require("aws-sdk");
AWS.config.credentials = new AWS.SharedIniFileCredentials({ profile: 'default' });
if (!AWS.config.region) {
	AWS.config.update({region: 'us-east-1'}); // Set default region to us-east-1 if not configured.
}
const lambda = require('aws-lambda-invoke');

//add redis endpoint below
var redis_client_pub = require('redis').createClient(6379, 'redisplacecache.ocp81l.0001.use1.cache.amazonaws.com', {no_ready_check: true});
var redis_client_sub = require('redis').createClient(6379, 'redisplacecache.ocp81l.0001.use1.cache.amazonaws.com', {no_ready_check: true});
redis_client_sub.subscribe("server-updates");

var colour_enum = {
	0:  "#FFFFFF",  // WHITE
	1:  "#E4E4E4",  // LIGHT-GREY
	2:  "#888888",  // GREY
	3:  "#222222",  // BLACK
	4:  "#FFA7D1",  // PINK
	5:  "#E50000",  // RED
	6:  "#E59500",  // ORANGE
	7:  "#A06A42",  // BROWN
	8:  "#E5D900",  // YELLOW
	9:  "#94E044",  // LIGHT-GREEN
	10: "#02BE01",  // GREEN
	11: "#00D3DD",  // TURQUOISE
	12: "#0083C7",  // SKY-BLUE
	13: "#0000EA",  // BLUE
	14: "#CF6EE4",  // LIGHT-PURPLE
	15: "#820080",  // PURPLE
}
var board;

wss.on('close', function() {
    console.log('disconnected');
});

wss.broadcast = function broadcast(data) {
  wss.clients.forEach(function each(client) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(data);
    }
  });
};

redis_client_sub.on("message", (channel, message) => {
  var o = JSON.parse(message);
  var offset = 1000 * o.data.y + o.data.x;
  board[offset] = o.data.colour;
  wss.broadcast(JSON.stringify(o));
  console.log('Received From Redis Subscription:', o);
});

// for heartbeat to make sure connection is alive
function noop() {}
function heartbeat() {
  this.isAlive = true;
}

function isValidSet(o){
	var isValid=false;
	try {
	   isValid =
		Number.isInteger(o.x) && o.x!=null && 0<=o.x && o.x<1000 &&
		Number.isInteger(o.y) && o.y!=null && 0<=o.y && o.y<1000 &&
		Number.isInteger(o.colour) && o.colour!=null && 0<=o.colour && o.colour<=15;
	} catch (err){
		isValid=false;
	}
	return isValid;
}
wss.on('connection', function(ws) {
	// heartbeat
  	ws.isAlive = true;
  	ws.on('pong', heartbeat);

	// send initial board
	var jsonBoardData = {};
	jsonBoardData["type"] = "all";
	jsonBoardData["data"] = board;
	ws.send(JSON.stringify(jsonBoardData));

	// when we get a message from the client
	ws.on('message', function(message) {
		var o = JSON.parse(message);
		if (isValidSet(o)) {
			var ip = ws._socket.remoteAddress;
			// Check with DynamoDB to see if the User has submitted an item in the past 5 minutes.
			lambda.invoke("putItem", {x: o.x, y: o.y, author: ip, color: o.colour}).then(result => {
				if (result.statusCode == 200) {
					console.log("Accepted & Inserted Row To DB: ", message);
					var colour_int = o.colour;
					o.colour = colour_enum[o.colour];
					var jsonTileData = {};
					jsonTileData["type"] = "single";
					jsonTileData["data"] = o;
					wss.broadcast(JSON.stringify(jsonTileData));

					redis_client_pub.publish("server-updates",JSON.stringify(jsonTileData));
					console.log("Published To Redis:", message);
					// Update the internal server board state.
					var offset = 1000 * o.y + o.x;
					board[offset] = o.colour;

					// Update the Redis cached board state.
					lambda.invoke('modifyTile', {offset: offset, colour: colour_int}).then(result => {
						if (result.statusCode == 200) {
							console.log("Successfully Added To Cache: ", message);
						}
					});
				} else if (result.statusCode == 403) {
					var jsonTileData = {};
					jsonTileData["type"] = "prevent";
					jsonTileData["data"] = {
						"msg": "You cannot replace a tile, it has not been five minutes since last tile placement"
					};
					ws.send(JSON.stringify(jsonTileData));
					console.log("Prevented User From Placing: ", message);
				} else {
					var jsonTileData = {};
					jsonTileData["type"] = "error";
					jsonTileData["data"] = {
						"msg": "DB Server Error"
					};
					ws.send(JSON.stringify(jsonTileData));
					console.log("DB Server Error From Adding: ", message);
				}
			});
		}
	});
});

// heartbeat (ping) sent to all clients
const interval = setInterval(function ping() {
  wss.clients.forEach(function each(ws) {
    if (ws.isAlive === false) return ws.terminate();

    ws.isAlive = false;
    ws.ping(noop);
  });
}, 30000);

// Static content
var express = require('express');
const { Route53Resolver, DataSync, Redshift } = require('aws-sdk');
var app = express();

// static_files has all of statically returned content: https://expressjs.com/en/starter/static-files.html
app.use('/',express.static('static_files'));

// Receive board state, then start the server.
lambda.invoke('getBoard').then(result => {
	board = result.body;
	for (var i = 0; i < board.length; i++) {
		board[i] = colour_enum[board[i]];
	}
	app.listen(8080, function () {
		console.log('Example app listening on port 8080!');
	});
});