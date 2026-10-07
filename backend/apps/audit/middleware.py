from . import context


class AuditoriaMiddleware:
    """Guarda la IP de cada petición (el usuario lo pone AuditJWTAuthentication)."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        token = context.iniciar(request.META.get("REMOTE_ADDR"))
        try:
            return self.get_response(request)
        finally:
            context.terminar(token)