from fastapi import WebSocket
from firebase_admin import auth

clients: list[WebSocket] = []

async def connect(ws: WebSocket):
    token = ws.query_params.get("token")

    if not token:
        await ws.close(code=1008)
        return None

    try:
        decoded_token = auth.verify_id_token(token)
        uid = decoded_token["uid"]
    except Exception:
        await ws.close(code=1008)
        return None

    await ws.accept()
    clients.append(ws)

    return uid


async def disconnect(ws: WebSocket):
    if ws in clients:
        clients.remove(ws)


async def broadcast(data: dict):
    disconnected_clients = []

    for ws in clients:
        try:
            await ws.send_json(data)
        except Exception:
            disconnected_clients.append(ws)

    for ws in disconnected_clients:
        await disconnect(ws)