from pathlib import Path

from django.contrib.auth import authenticate
from django.http import FileResponse
from django.utils import timezone
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.exceptions import NotFound
from rest_framework.parsers import MultiPartParser
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from apps.audit.services import registrar
from rest_framework.exceptions import Throttled

from .throttles import LoginEmailThrottle, LoginIPThrottle

from .serializers import (
    FotoSerializer,
    LoginSerializer,
    RefreshSerializer,
    TokensSerializer,
    UsuarioSerializer,
)
from .services import (
    AutenticacionFallida,
    emitir_tokens,
    guardar_foto,
    quitar_foto,
    renovar_tokens,
    revocar_token,
)


class LoginView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    
    throttle_classes = [LoginIPThrottle, LoginEmailThrottle]

    def throttled(self, request, wait):
        raise Throttled(
            wait=wait,
            detail="Demasiados intentos de inicio de sesión. Espera un minuto e inténtalo de nuevo.",
        )

    @extend_schema(request=LoginSerializer, responses=TokensSerializer)
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"]
        usuario = authenticate(
            request,
            email=email,
            password=serializer.validated_data["password"],
        )
        if usuario is None:
            registrar("login_fallido", "Usuario", "", {"email": email})
            raise AutenticacionFallida("Email o contraseña incorrectos.")

        disponibles = usuario.roles_disponibles()
        elegido = serializer.validated_data.get("rol", "").strip()
        if elegido:
            rol = next((r for r in disponibles if r.nombre == elegido), None)
            if rol is None:
                raise AutenticacionFallida("Tu cuenta no tiene ese rol.")
        elif len(disponibles) > 1:
            # Varios roles: la app debe preguntar con cuál entrar y volver a enviar.
            return Response(
                {"requiere_rol": True, "roles": [r.nombre for r in disponibles]}
            )
        else:
            rol = disponibles[0]

        usuario.activar_rol(rol)
        usuario.last_login = timezone.now()
        usuario.save(update_fields=["last_login"])
        registrar("login", "Usuario", usuario.pk, {"rol": rol.nombre}, usuario=usuario)
        return Response(
            {
                **emitir_tokens(usuario, rol.nombre),
                "usuario": UsuarioSerializer(usuario).data,
            }
        )


class RefreshView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    @extend_schema(request=RefreshSerializer, responses=TokensSerializer)
    def post(self, request):
        serializer = RefreshSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(renovar_tokens(serializer.validated_data["refresh"]))


class LogoutView(APIView):
    @extend_schema(request=RefreshSerializer, responses={204: None})
    def post(self, request):
        serializer = RefreshSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        revocar_token(serializer.validated_data["refresh"], request.user)
        registrar("logout", "Usuario", request.user.pk)
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(APIView):
    @extend_schema(responses=UsuarioSerializer)
    def get(self, request):
        return Response(UsuarioSerializer(request.user).data)


def respuesta_foto(usuario):
    """Entrega la imagen (solo con sesión iniciada; no se sirve como archivo público)."""
    if not usuario.foto:
        raise NotFound("El usuario no tiene foto.")
    try:
        abierto = usuario.foto.open("rb")
    except FileNotFoundError:
        raise NotFound("La foto ya no está disponible.")
    mime = "image/png" if Path(usuario.foto.name).suffix.lower() == ".png" else "image/jpeg"
    respuesta = FileResponse(abierto, content_type=mime)
    respuesta["X-Content-Type-Options"] = "nosniff"
    return respuesta


class MeFotoView(APIView):
    """Foto de perfil del usuario que inició sesión: ver, cambiar o quitar."""

    parser_classes = [MultiPartParser]

    @extend_schema(responses={200: OpenApiTypes.BINARY})
    def get(self, request):
        return respuesta_foto(request.user)

    @extend_schema(
        request={"multipart/form-data": FotoSerializer}, responses=UsuarioSerializer
    )
    def put(self, request):
        serializer = FotoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        usuario = guardar_foto(request.user, serializer.validated_data["foto"])
        return Response(UsuarioSerializer(usuario).data)

    @extend_schema(responses={204: None})
    def delete(self, request):
        quitar_foto(request.user)
        return Response(status=status.HTTP_204_NO_CONTENT)
