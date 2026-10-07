import django_filters

from .models import Auditoria, HistorialCambios, HistorialEstado


class _RangoFechas(django_filters.FilterSet):
    desde = django_filters.DateFilter(field_name="fecha", lookup_expr="date__gte")
    hasta = django_filters.DateFilter(field_name="fecha", lookup_expr="date__lte")


class AuditoriaFilter(_RangoFechas):
    class Meta:
        model = Auditoria
        fields = ["usuario", "accion", "entidad", "entidad_id"]


class HistorialCambiosFilter(_RangoFechas):
    class Meta:
        model = HistorialCambios
        fields = ["usuario", "entidad", "entidad_id", "campo"]


class HistorialEstadoFilter(_RangoFechas):
    class Meta:
        model = HistorialEstado
        fields = ["usuario", "entidad", "entidad_id", "estado_nuevo"]