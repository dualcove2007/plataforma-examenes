from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.parsers import MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .filters import UsuarioFilter
from .models import Permiso, Rol, Usuario
from .permissions import tiene_permiso
from .serializers import (
    FotoSerializer,
    PermisoSerializer,
    RolSerializer,
    UsuarioListSerializer,
    UsuarioWriteSerializer,
)
from .services import guardar_foto, quitar_foto
from .views import respuesta_foto


class UsuarioViewSet(viewsets.ModelViewSet):
    queryset = Usuario.objects.select_related("rol").order_by("id")
    permission_classes = [IsAuthenticated, tiene_permiso("usuarios.gestionar")]
    filterset_class = UsuarioFilter
    search_fields = ["nombre", "email"]
    ordering_fields = ["nombre", "email", "fecha_creacion"]

    def get_serializer_class(self):
        if self.action in ("list", "retrieve"):
            return UsuarioListSerializer
        return UsuarioWriteSerializer

    @extend_schema(
        request={"multipart/form-data": FotoSerializer},
        responses={200: OpenApiTypes.BINARY},
    )
    @action(
        detail=True,
        methods=["get", "put", "delete"],
        url_path="foto",
        parser_classes=[MultiPartParser],
    )
    def foto(self, request, pk=None):
        """Ver, cambiar o quitar la foto de cualquier usuario (solo quien gestiona usuarios)."""
        usuario = self.get_object()
        if request.method == "GET":
            return respuesta_foto(usuario)
        if request.method == "DELETE":
            quitar_foto(usuario)
            return Response(status=status.HTTP_204_NO_CONTENT)
        serializer = FotoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        usuario = guardar_foto(usuario, serializer.validated_data["foto"])
        return Response(UsuarioListSerializer(usuario).data)

    def perform_destroy(self, instance):
        # No se borra: se desactiva para conservar el historial y las relaciones.
        if instance.pk == self.request.user.pk:
            raise ValidationError("No puedes desactivar tu propia cuenta.")
        instance.activo = False
        instance.save(update_fields=["activo"])
        instance.refresh_tokens.update(revocado=True)


class RolViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    viewsets.GenericViewSet,
):
    queryset = Rol.objects.prefetch_related("permisos").order_by("id")
    serializer_class = RolSerializer
    permission_classes = [IsAuthenticated, tiene_permiso("roles.gestionar")]
    pagination_class = None


class PermisoViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Permiso.objects.order_by("nombre")
    serializer_class = PermisoSerializer
    permission_classes = [IsAuthenticated, tiene_permiso("roles.gestionar")]
    pagination_class = None