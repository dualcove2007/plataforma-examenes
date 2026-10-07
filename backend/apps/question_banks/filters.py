import django_filters

from .models import BancoPreguntas, Pregunta


class BancoFilter(django_filters.FilterSet):
    class Meta:
        model = BancoPreguntas
        fields = {"materia": ["exact"], "activo": ["exact"]}


class PreguntaFilter(django_filters.FilterSet):
    materia = django_filters.NumberFilter(field_name="banco__materia_id")
    puntaje_min = django_filters.NumberFilter(field_name="puntaje", lookup_expr="gte")
    puntaje_max = django_filters.NumberFilter(field_name="puntaje", lookup_expr="lte")

    class Meta:
        model = Pregunta
        fields = ["banco", "tipo", "dificultad", "activo"]