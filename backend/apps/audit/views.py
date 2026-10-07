from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated

from apps.authentication.permissions import tiene_permiso

from .filters import AuditoriaFilter, HistorialCambiosFilter, HistorialEstadoFilter
from .models import Auditoria, HistorialCambios, HistorialEstado
from .serializers import (
    AuditoriaSerializer,
    HistorialCambiosSerializer,
    HistorialEstadoSerializer,
)


class _ConsultaBase(viewsets.ReadOnlyModelViewSet):
    permission_classes = [IsAuthenticated, tiene_permiso("auditoria.ver")]
    ordering_fields = ["fecha", "id"]


class AuditoriaViewSet(_ConsultaBase):
    queryset = Auditoria.objects.select_related("usuario")
    serializer_class = AuditoriaSerializer
    filterset_class = AuditoriaFilter
    search_fields = ["accion", "entidad", "entidad_id", "usuario__email", "usuario__nombre"]


class HistorialCambiosViewSet(_ConsultaBase):
    queryset = HistorialCambios.objects.select_related("usuario")
    serializer_class = HistorialCambiosSerializer
    filterset_class = HistorialCambiosFilter
    search_fields = ["entidad", "campo", "valor_anterior", "valor_nuevo", "usuario__email"]


class HistorialEstadoViewSet(_ConsultaBase):
    queryset = HistorialEstado.objects.select_related("usuario")
    serializer_class = HistorialEstadoSerializer
    filterset_class = HistorialEstadoFilter
    search_fields = ["entidad", "estado_anterior", "estado_nuevo", "usuario__email"]