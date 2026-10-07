from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from apps.authentication.models import Rol
from apps.authentication.permissions import tiene_permiso

from . import services
from .filters import ResultadoFilter
from .models import Intento, ResultadoExamen
from .serializers import (
    CalificarSerializer,
    IniciarSerializer,
    IntentoDetalleSerializer,
    IntentoSerializer,
    ResponderSerializer,
    ResultadoDetalleSerializer,
    ResultadoSerializer,
)


class IntentoViewSet(
    mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet
):
    """Lo que hace el estudiante: iniciar, responder y enviar."""

    serializer_class = IntentoSerializer
    permission_classes = [IsAuthenticated, tiene_permiso("examenes.rendir")]
    filterset_fields = ["asignacion", "estado"]
    ordering_fields = ["fecha_inicio"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Intento.objects.none()
        return (
            Intento.objects.filter(asignacion__estudiante=self.request.user)
            .select_related("asignacion__examen")
            .order_by("-fecha_inicio")
        )

    @extend_schema(request=IniciarSerializer, responses={201: IntentoDetalleSerializer})
    def create(self, request):
        serializer = IniciarSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        intento, creado = services.iniciar_intento(
            request.user, serializer.validated_data["asignacion"]
        )
        return Response(
            IntentoDetalleSerializer(intento).data,
            status=status.HTTP_201_CREATED if creado else status.HTTP_200_OK,
        )

    def retrieve(self, request, *args, **kwargs):
        intento = services.refrescar_estado(self.get_object())
        en_progreso = intento.estado == Intento.Estado.EN_PROGRESO
        clase = IntentoDetalleSerializer if en_progreso else IntentoSerializer
        return Response(clase(intento).data)

    @extend_schema(request=ResponderSerializer, responses={200: OpenApiTypes.OBJECT})
    @action(detail=True, methods=["post"])
    def responder(self, request, pk=None):
        intento = self.get_object()
        serializer = ResponderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.responder(intento, **serializer.validated_data)
        return Response(
            {"guardada": True, "segundos_restantes": services.segundos_restantes(intento)}
        )

    @extend_schema(request=None, responses={200: ResultadoSerializer})
    @action(detail=True, methods=["post"])
    def enviar(self, request, pk=None):
        resultado = services.enviar_intento(self.get_object())
        return Response(
            ResultadoSerializer(resultado, context={"es_estudiante": True}).data
        )

    @extend_schema(responses={200: ResultadoSerializer})
    @action(detail=True, methods=["get"])
    def resultado(self, request, pk=None):
        intento = services.refrescar_estado(self.get_object())
        resultado = ResultadoExamen.objects.filter(intento=intento).first()
        if resultado is None:
            raise NotFound("El intento aún no tiene resultado.")
        return Response(
            ResultadoSerializer(resultado, context={"es_estudiante": True}).data
        )


class ResultadoViewSet(viewsets.ReadOnlyModelViewSet):
    """Lo que hace el docente (o el admin): ver resultados y calificar abiertas."""

    serializer_class = ResultadoSerializer
    permission_classes = [IsAuthenticated, tiene_permiso("resultados.ver_todos")]
    filterset_class = ResultadoFilter
    search_fields = [
        "intento__asignacion__estudiante__nombre",
        "intento__asignacion__estudiante__email",
    ]
    ordering_fields = ["nota_final", "puntaje_total", "intento__fecha_fin"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return ResultadoExamen.objects.none()
        queryset = ResultadoExamen.objects.select_related(
            "intento__asignacion__estudiante", "intento__asignacion__examen"
        ).order_by("-id")
        usuario = self.request.user
        if usuario.rol.nombre != Rol.ADMINISTRADOR:
            queryset = queryset.filter(intento__asignacion__examen__docente=usuario)
        return queryset

    @extend_schema(responses={200: ResultadoDetalleSerializer})
    def retrieve(self, request, *args, **kwargs):
        resultado = self.get_object()
        maximos = {
            i.pregunta_id: i.puntaje
            for i in resultado.intento.asignacion.examen.items.all()
        }
        return Response(
            ResultadoDetalleSerializer(resultado, context={"maximos": maximos}).data
        )

    @extend_schema(request=CalificarSerializer, responses={200: ResultadoSerializer})
    @action(
        detail=True,
        methods=["post"],
        permission_classes=[IsAuthenticated, tiene_permiso("resultados.calificar")],
    )
    def calificar(self, request, pk=None):
        resultado = self.get_object()
        serializer = CalificarSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        resultado = services.calificar_abiertas(
            resultado, serializer.validated_data["calificaciones"], request.user
        )
        return Response(ResultadoSerializer(resultado).data)


class MisResultadosViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = ResultadoSerializer
    permission_classes = [IsAuthenticated, tiene_permiso("resultados.ver_propios")]
    filterset_class = ResultadoFilter
    ordering_fields = ["intento__fecha_fin", "nota_final"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return ResultadoExamen.objects.none()
        return (
            ResultadoExamen.objects.filter(
                intento__asignacion__estudiante=self.request.user
            )
            .select_related(
                "intento__asignacion__estudiante", "intento__asignacion__examen"
            )
            .order_by("-id")
        )

    def get_serializer_context(self):
        contexto = super().get_serializer_context()
        contexto["es_estudiante"] = True
        return contexto