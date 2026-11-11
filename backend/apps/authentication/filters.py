import django_filters

from .models import Rol, Usuario


class UsuarioFilter(django_filters.FilterSet):
    # ?rol=<id> trae a quien tenga ese rol (principal o adicional).
    rol = django_filters.ModelChoiceFilter(
        field_name="roles", queryset=Rol.objects.all()
    )
    creado_desde = django_filters.DateFilter(
        field_name="fecha_creacion", lookup_expr="date__gte"
    )
    creado_hasta = django_filters.DateFilter(
        field_name="fecha_creacion", lookup_expr="date__lte"
    )

    class Meta:
        model = Usuario
        fields = {"activo": ["exact"]}