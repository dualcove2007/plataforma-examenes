from django.contrib.auth import authenticate
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from apps.audit.services import registrar
from rest_framework.exceptions import Throttled

from .throttles import LoginEmailThrottle, LoginIPThrottle

from .serializers import (
    LoginSerializer,
    RefreshSerializer,
    TokensSerializer,
    UsuarioSerializer,
)
from .services import AutenticacionFallida, emitir_tokens, renovar_tokens, revocar_token


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

        usuario.last_login = timezone.now()
        usuario.save(update_fields=["last_login"])
        registrar("login", "Usuario", usuario.pk, usuario=usuario)
        return Response(
            {**emitir_tokens(usuario), "usuario": UsuarioSerializer(usuario).data}
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