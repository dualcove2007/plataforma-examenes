import django_filters

from .models import Examen


class ExamenFilter(django_filters.FilterSet):
    inicio_desde = django_filters.DateFilter(
        field_name="fecha_inicio", lookup_expr="date__gte"
    )
    inicio_hasta = django_filters.DateFilter(
        field_name="fecha_inicio", lookup_expr="date__lte"
    )

    class Meta:
        model = Examen
        fields = ["estado", "materia"]