import django_filters

from .models import Notificacion


class NotificacionFilter(django_filters.FilterSet):
    desde = django_filters.DateFilter(field_name="fecha_creacion", lookup_expr="date__gte")
    hasta = django_filters.DateFilter(field_name="fecha_creacion", lookup_expr="date__lte")

    class Meta:
        model = Notificacion
        fields = ["leida", "tipo"]