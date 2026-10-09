from django.db.models import Count, Sum
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.authentication.permissions import tiene_permiso
from apps.authentication.models import Rol, Usuario

from . import services
from .filters import ExamenFilter
from .models import AsignacionExamen, Examen
from .serializers import (
    AgregarPreguntaSerializer,
    AsignacionSerializer,
    AsignarSerializer,
    EstudianteSerializer,
    ExamenDetalleSerializer,
    ExamenPreguntaSerializer,
    ExamenSerializer,
    MiExamenSerializer,
    QuitarPreguntaSerializer,
)


class ExamenViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated, tiene_permiso("examenes.gestionar")]
    filterset_class = ExamenFilter
    search_fields = ["titulo", "descripcion"]
    ordering_fields = ["titulo", "fecha_inicio", "fecha_creacion"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Examen.objects.none()
        queryset = (
            Examen.objects.filter(docente=self.request.user)
            .select_related("materia")
            .annotate(
                total_preguntas=Count("items", distinct=True),
                puntaje_total=Sum("items__puntaje"),
            )
            .order_by("-fecha_creacion")
        )
        if self.action == "retrieve":
            queryset = queryset.prefetch_related("items__pregunta__opciones")
        return queryset

    def get_serializer_class(self):
        if self.action == "retrieve":
            return ExamenDetalleSerializer
        return ExamenSerializer

    def perform_create(self, serializer):
        serializer.save(docente=self.request.user)

    def perform_update(self, serializer):
        services.exigir_borrador(serializer.instance)
        serializer.save()

    def perform_destroy(self, instance):
        if instance.estado != Examen.Estado.BORRADOR:
            raise ValidationError(
                "Solo se eliminan exámenes en borrador; archiva el examen en su lugar."
            )
        instance.delete()

    # --- Estados ---
    def _transicion(self, request, nuevo):
        examen = self.get_object()
        services.cambiar_estado(examen, nuevo, request.user)
        return Response({"id": examen.id, "estado": examen.estado})

    @extend_schema(request=None, responses={200: OpenApiTypes.OBJECT})
    @action(detail=True, methods=["post"])
    def publicar(self, request, pk=None):
        return self._transicion(request, Examen.Estado.PUBLICADO)

    @extend_schema(request=None, responses={200: OpenApiTypes.OBJECT})
    @action(detail=True, methods=["post"])
    def cerrar(self, request, pk=None):
        return self._transicion(request, Examen.Estado.CERRADO)

    @extend_schema(request=None, responses={200: OpenApiTypes.OBJECT})
    @action(detail=True, methods=["post"])
    def archivar(self, request, pk=None):
        return self._transicion(request, Examen.Estado.ARCHIVADO)

    # --- Preguntas del examen ---
    @extend_schema(
        request=AgregarPreguntaSerializer, responses={201: ExamenPreguntaSerializer}
    )
    @action(detail=True, methods=["post"], url_path="agregar-pregunta")
    def agregar_pregunta(self, request, pk=None):
        examen = self.get_object()
        serializer = AgregarPreguntaSerializer(
            data=request.data, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)
        item = services.agregar_pregunta(
            examen,
            serializer.validated_data["pregunta"],
            serializer.validated_data.get("puntaje"),
        )
        return Response(
            ExamenPreguntaSerializer(item).data, status=status.HTTP_201_CREATED
        )

    @extend_schema(request=QuitarPreguntaSerializer, responses={204: None})
    @action(detail=True, methods=["post"], url_path="quitar-pregunta")
    def quitar_pregunta(self, request, pk=None):
        examen = self.get_object()
        serializer = QuitarPreguntaSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.quitar_pregunta(examen, serializer.validated_data["pregunta"])
        return Response(status=status.HTTP_204_NO_CONTENT)

    # --- Asignaciones ---
    @extend_schema(request=AsignarSerializer, responses={200: OpenApiTypes.OBJECT})
    @action(
        detail=True,
        methods=["post"],
        permission_classes=[
            IsAuthenticated,
            tiene_permiso("examenes.gestionar"),
            tiene_permiso("examenes.asignar"),
        ],
    )
    def asignar(self, request, pk=None):
        examen = self.get_object()
        serializer = AsignarSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        nuevos, existentes = services.asignar_estudiantes(
            examen, serializer.validated_data["estudiantes"]
        )
        return Response({"asignados": nuevos, "ya_asignados": existentes})

    @extend_schema(responses={200: AsignacionSerializer(many=True)})
    @action(detail=True, methods=["get"])
    def asignaciones(self, request, pk=None):
        examen = self.get_object()
        queryset = examen.asignaciones.select_related("estudiante").order_by(
            "estudiante__nombre"
        )
        return Response(AsignacionSerializer(queryset, many=True).data)


class MisExamenesViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = MiExamenSerializer
    permission_classes = [IsAuthenticated, tiene_permiso("examenes.rendir")]
    filterset_fields = ["estado"]
    ordering_fields = ["fecha_asignacion", "examen__fecha_inicio"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return AsignacionExamen.objects.none()
        return (
            AsignacionExamen.objects.filter(
                estudiante=self.request.user,
                examen__estado__in=[Examen.Estado.PUBLICADO, Examen.Estado.CERRADO],
            )
            .select_related("examen__materia")
            .annotate(total_preguntas=Count("examen__items"))
            .order_by("examen__fecha_inicio")
        )
        

class EstudianteViewSet(viewsets.ReadOnlyModelViewSet):
    """Estudiantes activos, para que el docente los asigne a sus exámenes."""

    serializer_class = EstudianteSerializer
    permission_classes = [IsAuthenticated, tiene_permiso("examenes.asignar")]
    search_fields = ["nombre", "email"]
    ordering_fields = ["nombre"]

    def get_queryset(self):
        return Usuario.objects.filter(
            activo=True, rol__nombre=Rol.ESTUDIANTE
        ).order_by("nombre")