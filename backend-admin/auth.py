from fastapi import HTTPException, Depends, Header
from firebase_admin import auth as firebase_auth

# Verify Firebase Token
def verify_token(authorization: str = Header(None)):
    if not authorization:
        raise HTTPException(status_code=401, detail="Missing authorization header")

    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization format")

    try:
        token = authorization.split("Bearer ")[1].strip()
        decoded_token = firebase_auth.verify_id_token(token)
        return decoded_token

    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid or expired token: {str(e)}")

# Require Admin Role
def require_admin(user=Depends(verify_token)):
    from firebase import db
    uid = user['uid']

    # Check Firestore for admin role
    user_doc = db.collection("users").document(uid).get()
    if not user_doc.exists:
        raise HTTPException(status_code=403, detail="Admin access required")

    user_data = user_doc.to_dict()
    if user_data.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    return user