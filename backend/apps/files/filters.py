import django_filters

from .models import ArchivoAdjunto


class AdjuntoFilter(django_filters.FilterSet):
    class Meta:
        model = ArchivoAdjunto
        fields = ["pregunta", "examen", "tipo_mime"]