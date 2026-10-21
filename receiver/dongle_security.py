"""Token authentication for browser Basic-auth and native bearer clients."""
import base64
import hmac


def valid_token(headers, expected):
    if not expected or len(expected) < 32:
        return False
    authorization = headers.get("authorization", "")
    scheme, _, value = authorization.partition(" ")
    if scheme.lower() == "bearer":
        presented = value
    elif scheme.lower() == "basic":
        try:
            username, presented = base64.b64decode(value, validate=True).decode("utf-8").split(":", 1)
            if username != "admin":
                return False
        except (ValueError, UnicodeError):
            return False
    else:
        return False
    return hmac.compare_digest(presented.encode("utf-8"), expected.encode("utf-8"))


def same_origin(headers, scheme):
    """Non-browser clients may omit Origin; browsers must use this exact origin."""
    origin = headers.get("origin")
    return origin is None or origin == f"{scheme}://{headers.get('host', '')}"
