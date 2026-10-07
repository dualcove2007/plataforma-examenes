from django.contrib.auth import authenticate
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

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

    @extend_schema(request=LoginSerializer, responses=TokensSerializer)
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        usuario = authenticate(
            request,
            email=serializer.validated_data["email"],
            password=serializer.validated_data["password"],
        )
        if usuario is None:
            raise AutenticacionFallida("Email o contraseña incorrectos.")

        usuario.last_login = timezone.now()
        usuario.save(update_fields=["last_login"])
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
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(APIView):
    @extend_schema(responses=UsuarioSerializer)
    def get(self, request):
        return Response(UsuarioSerializer(request.user).data)