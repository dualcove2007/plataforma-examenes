from django.http import FileResponse
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound
from rest_framework.parsers import MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from . import services
from .filters import AdjuntoFilter
from .models import ArchivoAdjunto
from .serializers import ArchivoAdjuntoSerializer, SubirAdjuntoSerializer


class ArchivoAdjuntoViewSet(
    mixins.ListModelMixin,
    mixins.RetrieveModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    """Adjuntos (PDF/PNG/JPG) de preguntas y exámenes. La descarga pasa por la API."""

    serializer_class = ArchivoAdjuntoSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser]
    filterset_class = AdjuntoFilter
    search_fields = ["nombre_original"]
    ordering_fields = ["fecha_creacion", "nombre_original", "tamano"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return ArchivoAdjunto.objects.none()
        return services.adjuntos_visibles(self.request.user)

    @extend_schema(
        request={"multipart/form-data": SubirAdjuntoSerializer},
        responses={201: ArchivoAdjuntoSerializer},
    )
    def create(self, request):
        serializer = SubirAdjuntoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        adjunto = services.subir(request.user, **serializer.validated_data)
        return Response(
            ArchivoAdjuntoSerializer(adjunto).data, status=status.HTTP_201_CREATED
        )

    def perform_destroy(self, instance):
        services.eliminar(self.request.user, instance)

    @extend_schema(responses={200: OpenApiTypes.BINARY})
    @action(detail=True, methods=["get"])
    def descargar(self, request, pk=None):
        adjunto = self.get_object()
        try:
            abierto = adjunto.archivo.open("rb")
        except FileNotFoundError:
            raise NotFound("El archivo ya no está disponible.")
        respuesta = FileResponse(
            abierto,
            content_type=adjunto.tipo_mime,
            as_attachment=request.query_params.get("inline") != "1",
            filename=adjunto.nombre_original,
        )
        respuesta["X-Content-Type-Options"] = "nosniff"
        return respuesta