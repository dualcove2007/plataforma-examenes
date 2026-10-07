from django.db.models import Count
from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated

from apps.authentication.permissions import tiene_permiso

from .filters import BancoFilter, PreguntaFilter
from .models import BancoPreguntas, Materia, Pregunta
from .serializers import BancoSerializer, MateriaSerializer, PreguntaSerializer


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

    def perform_destroy(self, instance):
        instance.activo = False  # se desactiva, no se borra
        instance.save(update_fields=["activo"])


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

    def perform_destroy(self, instance):
        instance.activo = False  # se desactiva, no se borra
        instance.save(update_fields=["activo"])