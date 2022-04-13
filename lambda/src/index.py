import json
import logging
import os
import platform
import sys
import time
import structlog

seconds_since_epoch = int(time.time())
COLD_START = True

structlog.configure(processors=[structlog.processors.JSONRenderer()])
log = structlog.get_logger()

# ... and now the actual app
def lambda_handler(event, context):
  global COLD_START
  if COLD_START == True:
    log.msg(
      'Heeey from {0}'.format(context.aws_request_id),
      seconds_since_epoch = seconds_since_epoch,
      unique_id = context.aws_request_id,
      lambda_arn = context.invoked_function_arn,
      aws_region = 'us-east-1',
      python_system = platform.system(),
      python_processor = platform.processor(),
      python_node = platform.node(),
      python_release = platform.release(),
      python_version = platform.version(),
      python_machine = platform.machine(),
      runner = 'lambda',
      orchestartor = 'lambda',
      lambda_function_name = os.getenv('AWS_LAMBDA_FUNCTION_NAME'),
      lambda_function_version = os.getenv('AWS_LAMBDA_FUNCTION_VERSION'),
      lambda_size = os.getenv('AWS_LAMBDA_FUNCTION_MEMORY_SIZE'),
      lambda_trace_id = os.getenv('_X_AMZN_TRACE_ID'),
    )
    COLD_START = False

  message = 'Heeey from {0}'.format(context.aws_request_id)

  time.sleep(1)
  return {
    'statusCode': 200,
    'statusDescription': '200 OK',
    'isBase64Encoded': False,
    'headers': {
        'Content-Type': 'application/json',
    },
    'body': json.dumps({'message': message})
  }
