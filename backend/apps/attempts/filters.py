import django_filters

from .models import ResultadoExamen


class ResultadoFilter(django_filters.FilterSet):
    examen = django_filters.NumberFilter(field_name="intento__asignacion__examen_id")
    estudiante = django_filters.NumberFilter(
        field_name="intento__asignacion__estudiante_id"
    )

    class Meta:
        model = ResultadoExamen
        fields = ["estado_revision"]