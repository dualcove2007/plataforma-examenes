from django.db import transaction
from django.db.models import Count, ProtectedError
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.parsers import MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.authentication.permissions import tiene_permiso

from .filters import BancoFilter, PreguntaFilter
from .models import BancoPreguntas, Materia, Pregunta
from .serializers import (
    ArchivoImportacionSerializer,
    BancoSerializer,
    MateriaSerializer,
    PreguntaSerializer,
)
from .services import (
    exportar_preguntas,
    generar_plantilla,
    importar_preguntas,
    respuesta_excel,
)


def eliminar_o_desactivar(instancia, mensaje_desactivado):
    """Borra el registro; si otros datos dependen de él (PROTECT), solo lo desactiva.

    Así se conserva el historial de exámenes, respuestas y resultados.
    Responde 200 con {"accion": "eliminado" | "desactivado", "mensaje": ...}.
    """
    try:
        with transaction.atomic():
            instancia.delete()
    except ProtectedError:
        instancia.activo = False
        instancia.save(update_fields=["activo"])
        return Response({"accion": "desactivado", "mensaje": mensaje_desactivado})
    return Response({"accion": "eliminado", "mensaje": "Eliminado correctamente."})


class MateriaViewSet(viewsets.ModelViewSet):
    queryset = Materia.objects.order_by("nombre")
    serializer_class = MateriaSerializer
    search_fields = ["nombre"]
    ordering_fields = ["nombre"]

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [IsAuthenticated()]
        return [IsAuthenticated(), tiene_permiso("materias.gestionar")()]


class BancoViewSet(viewsets.ModelViewSet):
    serializer_class = BancoSerializer
    permission_classes = [IsAuthenticated, tiene_permiso("bancos.gestionar")]
    filterset_class = BancoFilter
    search_fields = ["titulo", "descripcion"]
    ordering_fields = ["titulo", "fecha_creacion"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return BancoPreguntas.objects.none()
        return (
            BancoPreguntas.objects.filter(docente=self.request.user)
            .select_related("materia", "docente")
            .annotate(total_preguntas=Count("preguntas"))
            .order_by("-fecha_creacion")
        )

    def perform_create(self, serializer):
        serializer.save(docente=self.request.user)

    @extend_schema(responses={200: OpenApiTypes.OBJECT})
    def destroy(self, request, *args, **kwargs):
        # Sin preguntas se borra de verdad; con preguntas solo se desactiva.
        return eliminar_o_desactivar(
            self.get_object(),
            "El banco tiene preguntas: se desactivó en lugar de eliminarse.",
        )

    @extend_schema(
        request=ArchivoImportacionSerializer, responses={201: OpenApiTypes.OBJECT}
    )
    @action(
        detail=True,
        methods=["post"],
        parser_classes=[MultiPartParser],
        permission_classes=[
            IsAuthenticated,
            tiene_permiso("bancos.gestionar"),
            tiene_permiso("preguntas.gestionar"),
        ],
    )
    def importar(self, request, pk=None):
        banco = self.get_object()
        if not banco.activo:
            raise ValidationError("El banco está inactivo.")
        serializer = ArchivoImportacionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        total = importar_preguntas(serializer.validated_data["archivo"], banco, request)
        return Response({"importadas": total}, status=status.HTTP_201_CREATED)


class PreguntaViewSet(viewsets.ModelViewSet):
    serializer_class = PreguntaSerializer
    permission_classes = [IsAuthenticated, tiene_permiso("preguntas.gestionar")]
    filterset_class = PreguntaFilter
    search_fields = ["enunciado"]
    ordering_fields = ["dificultad", "puntaje", "id"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Pregunta.objects.none()
        return (
            Pregunta.objects.filter(banco__docente=self.request.user)
            .select_related("banco")
            .prefetch_related("opciones")
            .order_by("-id")
        )

    @extend_schema(responses={200: OpenApiTypes.OBJECT})
    def destroy(self, request, *args, **kwargs):
        # Sin uso se borra de verdad; si está en un examen o tiene respuestas, solo se desactiva.
        return eliminar_o_desactivar(
            self.get_object(),
            "La pregunta ya se usa en un examen o tiene respuestas: "
            "se desactivó en lugar de eliminarse.",
        )

    def perform_update(self, serializer):
        pregunta = serializer.instance
        cambia_contenido = set(serializer.validated_data) - {"activo"}
        if cambia_contenido and pregunta.en_examenes.exclude(
            examen__estado="borrador"
        ).exists():
            raise ValidationError(
                "La pregunta ya se usa en un examen publicado: "
                "desactívala y crea una nueva."
            )
        serializer.save()

    @extend_schema(responses={200: OpenApiTypes.BINARY})
    @action(detail=False, methods=["get"])
    def exportar(self, request):
        queryset = self.filter_queryset(self.get_queryset())
        return respuesta_excel(exportar_preguntas(queryset), "preguntas.xlsx")

    @extend_schema(responses={200: OpenApiTypes.BINARY})
    @action(detail=False, methods=["get"])
    def plantilla(self, request):
        return respuesta_excel(generar_plantilla(), "plantilla_preguntas.xlsx")