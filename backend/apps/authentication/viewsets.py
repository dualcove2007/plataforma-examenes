from rest_framework import mixins, viewsets
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated

from .filters import UsuarioFilter
from .models import Permiso, Rol, Usuario
from .permissions import tiene_permiso
from .serializers import (
    PermisoSerializer,
    RolSerializer,
    UsuarioListSerializer,
    UsuarioWriteSerializer,
)


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