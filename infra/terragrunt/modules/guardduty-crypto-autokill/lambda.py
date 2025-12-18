import json
import os
import boto3

ec2 = boto3.client("ec2")
sns = boto3.client("sns")

SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
STOP_INSTANCES = os.environ.get("STOP_INSTANCES", "true").lower() == "true"


def _extract_instance_id(event: dict) -> str | None:
    """
    GuardDuty finding payload typically includes:
    detail.resource.instanceDetails.instanceId
    """
    try:
        return (
            event["detail"]["resource"]["instanceDetails"]["instanceId"]
        )
    except Exception:
        return None


def _publish(subject: str, message: str) -> None:
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject[:100],  # SNS subject limit protection
        Message=message,
    )


def handler(event, context):
    finding_id = event.get("detail", {}).get("id", "unknown")
    finding_type = event.get("detail", {}).get("type", "unknown")
    region = event.get("region", "unknown")
    account = event.get("account", "unknown")
    severity = event.get("detail", {}).get("severity", "unknown")

    instance_id = _extract_instance_id(event)
    if not instance_id:
        _publish(
            subject="GuardDuty crypto auto-kill: unable to extract instance",
            message=json.dumps(event, indent=2)[:20000],
        )
        return {"ok": False, "reason": "no_instance_id"}

    action_taken = "none"
    stop_result = None

    if STOP_INSTANCES:
        try:
            stop_result = ec2.stop_instances(InstanceIds=[instance_id])
            action_taken = "stop_instances"
        except Exception as e:
            action_taken = f"stop_failed: {e!r}"

    msg = {
        "summary": "GuardDuty cryptomining response",
        "account": account,
        "region": region,
        "finding_id": finding_id,
        "finding_type": finding_type,
        "severity": severity,
        "instance_id": instance_id,
        "action_taken": action_taken,
        "stop_result": stop_result,
    }

    _publish(
        subject="GuardDuty crypto auto-kill triggered",
        message=json.dumps(msg, indent=2)[:20000],
    )

    return {"ok": True, **msg}
