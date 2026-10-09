from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.exceptions import ValidationError

from . import services
from .filters import NotificacionFilter
from .models import Notificacion
from .serializers import NotificacionSerializer


class NotificacionViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    """Cada usuario ve solo SUS notificaciones (cualquier rol autenticado)."""

    serializer_class = NotificacionSerializer
    permission_classes = [IsAuthenticated]
    filterset_class = NotificacionFilter
    search_fields = ["titulo", "mensaje"]
    ordering_fields = ["fecha_creacion", "leida"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Notificacion.objects.none()
        return Notificacion.objects.filter(usuario=self.request.user)
    
    def perform_destroy(self, instance):
        if not instance.leida:
            raise ValidationError("Solo puedes eliminar notificaciones ya leídas.")
        instance.delete()

    @extend_schema(request=None, responses={200: NotificacionSerializer})
    @action(detail=True, methods=["post"], url_path="marcar-leida")
    def marcar_leida(self, request, pk=None):
        notificacion = services.marcar_leida(self.get_object())
        return Response(NotificacionSerializer(notificacion).data)

    @extend_schema(request=None, responses={200: OpenApiTypes.OBJECT})
    @action(detail=False, methods=["post"], url_path="marcar-todas")
    def marcar_todas(self, request):
        return Response({"marcadas": services.marcar_todas(request.user)})

    @extend_schema(responses={200: OpenApiTypes.OBJECT})
    @action(detail=False, methods=["get"], url_path="no-leidas")
    def no_leidas(self, request):
        return Response({"no_leidas": services.contar_no_leidas(request.user)})
    

    @extend_schema(request=None, responses={200: OpenApiTypes.OBJECT})
    @action(detail=False, methods=["delete"], url_path="eliminar-leidas")
    def eliminar_leidas(self, request):
        return Response({"eliminadas": services.eliminar_leidas(request.user)})