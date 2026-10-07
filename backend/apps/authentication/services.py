import hashlib
from datetime import datetime, timezone as dt_timezone

from django.utils import timezone
from rest_framework.exceptions import APIException
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken as JWTRefreshToken

from .models import RefreshToken


class AutenticacionFallida(APIException):
    status_code = 401
    default_detail = "Credenciales o token inválidos."
    default_code = "autenticacion_fallida"


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def emitir_tokens(usuario):
    refresh = JWTRefreshToken.for_user(usuario)
    refresh["rol"] = usuario.rol.nombre
    expira = datetime.fromtimestamp(refresh["exp"], tz=dt_timezone.utc)
    RefreshToken.objects.create(
        usuario=usuario,
        token_hash=_hash(str(refresh)),
        fecha_expiracion=expira,
    )
    return {"access": str(refresh.access_token), "refresh": str(refresh)}


def renovar_tokens(refresh_str):
    try:
        JWTRefreshToken(refresh_str)  # valida firma y expiración
    except TokenError:
        raise AutenticacionFallida("Refresh token inválido o expirado.")

    registro = (
        RefreshToken.objects.select_related("usuario__rol")
        .filter(
            token_hash=_hash(refresh_str),
            revocado=False,
            fecha_expiracion__gt=timezone.now(),
        )
        .first()
    )
    if registro is None or not registro.usuario.activo:
        raise AutenticacionFallida("Refresh token revocado o usuario inactivo.")

    registro.revocado = True  # rotación: cada refresh se usa una sola vez
    registro.save(update_fields=["revocado"])
    return emitir_tokens(registro.usuario)


def revocar_token(refresh_str, usuario):
    RefreshToken.objects.filter(
        token_hash=_hash(refresh_str), usuario=usuario
    ).update(revocado=True)