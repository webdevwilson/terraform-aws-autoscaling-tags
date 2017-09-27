import boto3
import json
import logging
import os

MARKER = "lambda:autoscaling_add_tags"

# Configure logging
LOG_LEVEL=os.environ.get('LOG_LEVEL', 'INFO')
logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(LOG_LEVEL)

session = boto3.session.Session()

autoscaling = session.client('autoscaling')
ec2 = session.client('ec2')

def handler(event, context):
    message = json.loads(event['Records'][0]['Sns']['Message'])

    if message.get('Event', None) == 'autoscaling:TEST_NOTIFICATION':
        logger.info('Received test notification')
        return

    # get local variables from the message
    autoscaling_group_name = message['AutoScalingGroupName']
    instance_id = message['EC2InstanceId']
    lifecycle_action_token = message['LifecycleActionToken']
    lifecycle_hook_name = message['LifecycleHookName']
    notification_metadata = json.loads(message['NotificationMetadata'])

    logger.info("autoscaling_group_name: %s", autoscaling_group_name)
    logger.info("instance_id: %s", instance_id)
    logger.info("lifecycle_action_token: %s", lifecycle_action_token)
    logger.info("lifecycle_hook_name: %s", lifecycle_hook_name)
    logger.info("notification_metadata: %s", notification_metadata)

    # go ahead and continue the lifecycle
    try:
        tags = []
        for i in notification_metadata.items():
            tags.append({
                'Key': i[0],
                'Value': i[1],
            })
        logger.info("Adding tags to EC2 instance %s", tags)
        ec2.create_tags(
            Resources=[
                instance_id,
            ],
            Tags=tags
        )
    except Exception as e:
        logger.error(e)
        raise e
    finally:
        logger.info("Completing lifecycle action")
        autoscaling.complete_lifecycle_action(
            AutoScalingGroupName=autoscaling_group_name,
            InstanceId=instance_id,
            LifecycleActionResult='CONTINUE',
            LifecycleActionToken=lifecycle_action_token,
            LifecycleHookName=lifecycle_hook_name)