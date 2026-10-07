from rest_framework_simplejwt.authentication import JWTAuthentication

from . import context


class AuditJWTAuthentication(JWTAuthentication):
    """Igual que JWTAuthentication, pero deja el usuario disponible para la auditoría."""

    def authenticate(self, request):
        resultado = super().authenticate(request)
        if resultado is not None:
            context.asignar_usuario(resultado[0])
        return resultado