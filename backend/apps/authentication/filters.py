import django_filters

from .models import Usuario


class UsuarioFilter(django_filters.FilterSet):
    creado_desde = django_filters.DateFilter(
        field_name="fecha_creacion", lookup_expr="date__gte"
    )
    creado_hasta = django_filters.DateFilter(
        field_name="fecha_creacion", lookup_expr="date__lte"
    )

    class Meta:
        model = Usuario
        fields = {"rol": ["exact"], "activo": ["exact"]}