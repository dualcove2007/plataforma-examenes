from rest_framework_simplejwt.authentication import JWTAuthentication
from drf_spectacular.extensions import OpenApiAuthenticationExtension

from . import context


class AuditJWTAuthentication(JWTAuthentication):
    """Igual que JWTAuthentication, pero deja el usuario disponible para la auditoría."""

    def authenticate(self, request):
        resultado = super().authenticate(request)
        if resultado is not None:
            usuario, token = resultado
            # Con varios roles, la sesión usa el rol elegido al iniciar (va en el token).
            elegido = token.get("rol")
            if elegido and elegido != usuario.rol.nombre:
                rol = next(
                    (r for r in usuario.roles_disponibles() if r.nombre == elegido),
                    None,
                )
                if rol is not None:
                    usuario.activar_rol(rol)
            context.asignar_usuario(usuario)
        return resultado
    
    


class AuditJWTScheme(OpenApiAuthenticationExtension):
    target_class = "apps.audit.authentication.AuditJWTAuthentication"
    name = "jwtAuth"

    def get_security_definition(self, auto_schema):
        return {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"}