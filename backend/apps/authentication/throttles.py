import hashlib

from rest_framework.throttling import SimpleRateThrottle


class LoginIPThrottle(SimpleRateThrottle):
    """Límite de intentos de login por IP (REMOTE_ADDR, igual que la auditoría).

    No se usa X-Forwarded-For porque el cliente puede falsificarlo.
    """

    scope = "login_ip"

    def get_cache_key(self, request, view):
        ip = request.META.get("REMOTE_ADDR", "")
        return self.cache_format % {"scope": self.scope, "ident": ip}


class LoginEmailThrottle(SimpleRateThrottle):
    """Límite por correo, para frenar ataques repartidos entre varias IP."""

    scope = "login_email"

    def get_cache_key(self, request, view):
        datos = request.data
        email = str(datos.get("email", "")) if hasattr(datos, "get") else ""
        email = email.strip().lower()
        if not email:
            return None
        ident = hashlib.sha256(email.encode()).hexdigest()
        return self.cache_format % {"scope": self.scope, "ident": ident}