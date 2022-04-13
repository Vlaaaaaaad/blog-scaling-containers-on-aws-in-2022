"""Tiny app to track container scaling performance."""
import json
import logging
import os
import platform
import sys
import time

import libhoney
import requests
from flask import Flask
from flask_cors import CORS
from pythonjsonlogger import jsonlogger

seconds_since_epoch = int(time.time())
HTTP_OK = 200
APP_VERSION = 'dev'
details = {}

logger = logging.getLogger()
logHandler = logging.StreamHandler()
formatter = jsonlogger.JsonFormatter()
logHandler.setFormatter(formatter)
logger.addHandler(logHandler)

def get_ec2_idms_value(path):
    """Gets a specific value from EC2 IDMSv2."""
    idms2_auth_token_response = requests.put(
        'http://169.254.169.254/latest/api/token',
        headers={
            'X-aws-ec2-metadata-token-ttl-seconds': '60',
        },
        timeout=3,
    )
    if idms2_auth_token_response.status_code != HTTP_OK:
        raise RuntimeError(
            'IDMS2 auth failed: {0}'.format(idms2_auth_token_response.text),
        )

    idms2_value = requests.get(
        url='http://169.254.169.254/latest/meta-data/{0}'.format(path),
        headers={
            'X-aws-ec2-metadata-token': idms2_auth_token_response.text,
        },
    )
    if idms2_value.status_code != HTTP_OK:
        raise RuntimeError(
            'Unexpected IDMSv2 reponse: {0}'.format(idms2_value.text),
        )

    return idms2_value.text



details['seconds_since_epoch'] = seconds_since_epoch
details['aws_region'] = 'us-east-1'
details['python_system'] = platform.system()
details['python_processor'] = platform.processor()
details['python_node'] = platform.node()
details['python_release'] = platform.release()
details['python_version'] = platform.version()
details['python_machine'] = platform.machine()
details['app_version'] = APP_VERSION

if os.getenv('VLAAAAAAAD_RUNNER_TYPE') is None:
    from libhoney.transmission import FileTransmission
    libhoney.init(
        transmission_impl=FileTransmission(output=sys.stdout),
        debug=True,
    )
else:
    libhoney.init(
        writekey='haha',
        dataset='scaling-events-test',
    )

if os.getenv('VLAAAAAAAD_RUNNER_TYPE') == 'ec2':
    details['runner'] = 'ec2'
    details['aws_az_id'] = get_ec2_idms_value('placement/availability-zone-id')
    details['aws_az'] = get_ec2_idms_value('placement/availability-zone')
    details['ec2_hostname'] = get_ec2_idms_value('hostname')
    details['ec2_instance_id'] = get_ec2_idms_value('instance-id')
    details['ec2_instance_type'] = get_ec2_idms_value('instance-type')
    details['aws_purchase_type'] = 'spot'

if os.getenv('VLAAAAAAAD_ORCHESTRATOR_TYPE') == 'ecs':
    details['orchestartor'] = 'ecs'
    details['ecs_service_count'] = os.getenv('VLAAAAAAAD_ECS_SERVICE_COUNT')

    ecs_container_metadata_v4 = {}
    request = requests.get(
        url='{0}/{1}'.format(os.getenv('ECS_CONTAINER_METADATA_URI_V4'), 'task'),
        timeout=3,
    )
    if request.status_code == HTTP_OK:
        ecs_container_metadata_v4 = json.loads(request.text)
    else:
        raise RuntimeError('ECS metadata failed:{0}'.format(request.text))

    logger.critical(json.dumps(ecs_container_metadata_v4))

    details['cluster'] = ecs_container_metadata_v4['Cluster']
    details['task_id'] = ecs_container_metadata_v4['TaskARN']
    details['unique_id'] = ecs_container_metadata_v4['TaskARN']
    details['image_pull_started_at'] = ecs_container_metadata_v4['PullStartedAt']
    details['image_pull_stopped_at'] = ecs_container_metadata_v4['PullStoppedAt']
    details['aws_az'] = ecs_container_metadata_v4['AvailabilityZone']
    if ecs_container_metadata_v4['Containers'][0]['Name'] == 'app':
        details['container_id'] = ecs_container_metadata_v4['Containers'][0]['DockerId']
        details['container_arn'] = ecs_container_metadata_v4['Containers'][0]['ContainerARN']
        details['container_created_at'] = ecs_container_metadata_v4['Containers'][0]['CreatedAt']
        details['container_started_at'] = ecs_container_metadata_v4['Containers'][0]['StartedAt']
        details['container_image_sha'] = ecs_container_metadata_v4['Containers'][0]['ImageID']
    else:
        details['container_id'] = ecs_container_metadata_v4['Containers'][1]['DockerId']
        details['container_arn'] = ecs_container_metadata_v4['Containers'][1]['ContainerARN']
        details['container_created_at'] = ecs_container_metadata_v4['Containers'][1]['CreatedAt']
        details['container_started_at'] = ecs_container_metadata_v4['Containers'][1]['StartedAt']
        details['container_image_sha'] = ecs_container_metadata_v4['Containers'][1]['ImageID']

    if os.getenv('VLAAAAAAAD_RUNNER_TYPE') == 'fargate':
        details['runner'] = 'fargate'

        match platform.machine():
            case 'aarch64':
                details['aws_purchase_type'] = 'on-demand' # ECS on Fargate ARM is On-Demand only
            case 'x86_64':
                if platform.system() == 'Linux':
                    details['aws_purchase_type'] = 'spot' # ECS on Fargate Spot is used by default
                else:
                    details['aws_purchase_type'] = 'on-demand' # ECS on Fargate Windows is On-Demand only
            case _:
                details['aws_purchase_type'] = 'wtf-no-idea'
        if platform.system() == 'Linux':
            details['container_clock_error_bound'] = ecs_container_metadata_v4['ClockDrift']['ClockErrorBound']
            details['container_reference_timestamp'] = ecs_container_metadata_v4['ClockDrift']['ReferenceTimestamp']
            details['container_clock_synchronization_status'] = ecs_container_metadata_v4['ClockDrift']['ClockSynchronizationStatus']
elif os.getenv('VLAAAAAAAD_ORCHESTRATOR_TYPE') == 'eks':
    details['k8s_pod_name'] = os.getenv('MY_POD_NAME')
    details['k8s_pod_hostname'] = os.getenv('MY_NODE_NAME')
    details['k8s_pod_ip'] = os.getenv('MY_POD_IP')
    details['k8s_pod_uid'] = os.getenv('MY_POD_UID')
    details['unique_id'] = os.getenv('MY_POD_UID')

    if os.getenv('VLAAAAAAAD_RUNNER_TYPE') == 'fargate':
        details['runner'] = 'fargate'
        details['aws_purchase_type'] = 'on-demand'
    else:
        details['k8s_pod_scaler'] = os.getenv('MY_K8S_SCALER')
elif os.getenv('VLAAAAAAAD_ORCHESTRATOR_TYPE') == 'apprunner':
    details['runner'] = 'apprunner'
    details['orchestartor'] = 'apprunner'

    request = requests.get(
        url=os.getenv('ECS_CONTAINER_METADATA_URI_V4'),
    )
    if request.status_code != HTTP_OK:
        raise RuntimeError(
            'Unexpected AppRunner ECS metadata reponse: {0}'.format(request.text),
        )
    else:
        apprunner_container_metadata_v4 = json.loads(request.text)

    details['container_id'] = apprunner_container_metadata_v4['DockerId']
    details['unique_id'] = apprunner_container_metadata_v4['ContainerARN']
    details['container_arn'] = apprunner_container_metadata_v4['ContainerARN']
    details['container_created_at'] = apprunner_container_metadata_v4['CreatedAt']
    details['container_started_at'] = apprunner_container_metadata_v4['StartedAt']
    details['container_image_sha'] = apprunner_container_metadata_v4['ImageID']

logger.critical(details)
ev = libhoney.new_event()
ev.add(details)
ev.send()
libhoney.flush()  # Blocking flush


# ... and now the actual app
app = Flask(__name__)
cors = CORS(app)


@app.route('/status/alive', methods=['GET'])
def alive():
    """Status check function to verify the server can start.

    Returns:
        JSON-formated response.
    """
    response = {
        'status': 'Greeter service is alive',
    }

    return app.response_class(
        response=json.dumps(response),
        status=HTTP_OK,
        mimetype='application/json',
    )


@app.route('/status/healthy', methods=['GET'])
def healthy():
    """Status check function to verify the server can serve requests.

    Returns:
        JSON-formated response.
    """
    response = {
        'status': 'Greeter service is healthy',
    }

    return app.response_class(
        response=json.dumps(response),
        status=HTTP_OK,
        mimetype='application/json',
    )


@app.route('/', methods=['GET'])
def index():
    """Return a greeting.

    Returns:
        JSON-formated response.
    """
    greeting = {
        'greeting': 'hello',
    }

    return app.response_class(
        response=json.dumps(greeting),
        status=HTTP_OK,
        mimetype='application/json',
    )


@app.after_request
def after_request_func(response):
    """Add helpful headers to the response.

    Args:
        response: the Flask-provided response object.

    Returns:
        Proper response, with added headers.
    """
    response.headers['X-Reply-Service'] = 'greeter-service'
    response.headers['X-Version'] = APP_VERSION
    return response
