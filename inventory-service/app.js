/**
 * Main application file.
 */
'use strict';

// Set default server port to 8080
var port = process.env.PORT || 8080;

const express = require('express');
const winston = require('winston');
var bodyParser = require('body-parser');
const { Tags, FORMAT_HTTP_HEADERS } = require('opentracing')

var initTracer = require('jaeger-client').initTracer;

var isArray = function(a) {
  return (!!a) && (a.constructor === Array);
};

const app = express()
winston.level = process.env.LOG_LEVEL || 'debug';

// Tracing configuration if provided
var jaegerHost = process.env.JAEGER_SERVER_HOSTNAME || 'localhost';
var jaegerPort = process.env.JAEGER_SERVER_PORT || 6832;
var config = {
  'serviceName': 'inventory-service',
  'reporter': {
    'logSpans': true,
    'agentHost': jaegerHost,
    'agentPort': jaegerPort
    //'flushIntervalMs': 100
  },
  'sampler': {
    'type': 'probabilistic',
    'param': 1.0
  }
};
var options = {
  'tags': {
    'inventory-service': '0.1.0'
  },
  'logger': winston
};
var tracer = initTracer(config, options);

app.use(bodyParser.json()); // for parsing application/json

app.get('/health', function (req, res) {
  res.status(200).send('Inventory Service is alive');
})

app.get('/checkAvailable/:productId', function (req, res) {
  // OpenTracing context init and spans.
  var span;
  const parentSpanContext = tracer.extract(FORMAT_HTTP_HEADERS, req.headers);
  if (parentSpanContext) {
    span = tracer.startSpan('http_server', {
      childOf: parentSpanContext
    });
  } else {
    span = tracer.startSpan('http_server');
  }
  span.setTag(Tags.HTTP_URL, '/checkAvailable/:productId');
  span.setTag(Tags.HTTP_METHOD, 'GET');

  // Process request.
  if (req.params.productId === "1") {
    span.setTag(Tags.HTTP_STATUS_CODE, 200);
    span.log({'event': 'Product is available'});
    var waitTill = new Date(new Date().getTime() + 66);
    while (waitTill > new Date()) {}
    span.finish();
    res.status(200).send('Available product found in Inventory');
  } else {
    span.setTag(Tags.HTTP_STATUS_CODE, 404);
    span.log({'event': 'Product is not available'});
    var waitTill = new Date(new Date().getTime() + 77);
    while (waitTill > new Date()) {}
    span.finish();
    res.status(404).send('No available product found in Inventoty');
  }
})

app.listen(port, function () {
  console.log('MSA Inventory Service listening on port: ' + port);
})
