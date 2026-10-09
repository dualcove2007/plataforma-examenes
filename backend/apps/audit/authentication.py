from rest_framework_simplejwt.authentication import JWTAuthentication
from drf_spectacular.extensions import OpenApiAuthenticationExtension

from . import context


class AuditJWTAuthentication(JWTAuthentication):
    """Igual que JWTAuthentication, pero deja el usuario disponible para la auditoría."""

    def authenticate(self, request):
        resultado = super().authenticate(request)
        if resultado is not None:
            context.asignar_usuario(resultado[0])
        return resultado
    
    


class AuditJWTScheme(OpenApiAuthenticationExtension):
    target_class = "apps.audit.authentication.AuditJWTAuthentication"
    name = "jwtAuth"

    def get_security_definition(self, auto_schema):
        return {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"}