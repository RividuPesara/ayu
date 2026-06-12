import logging
from datetime import datetime, timezone

from firebase_admin import firestore, messaging

from app.core.firebase import get_firestore_client

logger = logging.getLogger(__name__)

USERS_COLLECTION = "users"
NOTIFICATIONS_COLLECTION = "notifications"


def send_push(
    uid: str,
    title: str,
    body: str,
    notif_type: str,
    route: str,
    dedupe_key: str,
    priority: str = "normal",
) -> None:
    db = get_firestore_client()

    # idempotency check skip if already sent
    notif_ref = (
        db.collection(NOTIFICATIONS_COLLECTION)
        .document(uid)
        .collection("items")
        .document(dedupe_key)
    )
    if notif_ref.get().exists:
        logger.info("Push already sent for dedupe_key=%s uid=%s", dedupe_key, uid)
        return

    # write in app doc first so it survives even if push fails
    notif_ref.set({
        "title": title,
        "subtitle": body,
        "type": notif_type,
        "priority": priority,
        "source": "push",
        "route": route,
        "isRead": False,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "fireAt": None,
        "deliveredAt": None,
    })

    # read all enabled device tokens for this user
    devices = (
        db.collection(USERS_COLLECTION)
        .document(uid)
        .collection("devices")
        .where("enabled", "==", True)
        .stream()
    )

    tokens = []
    device_ids = []
    for dev in devices:
        data = dev.to_dict() or {}
        token = data.get("fcmToken")
        if token:
            tokens.append(token)
            device_ids.append(dev.id)

    if not tokens:
        logger.info("No enabled devices for uid=%s, in-app doc written", uid)
        return

    # pick the android notification channel based on priority
    android_channel = "ayu_crisis" if priority == "high" else "ayu_default"

    message = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(title=title, body=body),
        android=messaging.AndroidConfig(
            notification=messaging.AndroidNotification(
                channel_id=android_channel,
                priority="high" if priority == "high" else "default",
            ),
            priority="high",
        ),
        data={"route": route, "type": notif_type},
    )

    response = messaging.send_each_for_multicast(message)
    logger.info(
        "Push sent uid=%s tokens=%d success=%d failure=%d",
        uid, len(tokens), response.success_count, response.failure_count,
    )

    # prune dead tokens so we stop pushing to unregistered devices
    dead_errors = {"UNREGISTERED", "INVALID_ARGUMENT"}
    for i, result in enumerate(response.responses):
        if not result.success and result.exception:
            code = getattr(result.exception, "code", "") or ""
            if any(e in str(code).upper() for e in dead_errors):
                device_id = device_ids[i]
                db.collection(USERS_COLLECTION).document(uid).collection("devices").document(device_id).delete()
                logger.info("Pruned dead device token device_id=%s uid=%s", device_id, uid)
