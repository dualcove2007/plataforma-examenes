from rest_framework import serializers

from .models import Notificacion


class NotificacionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notificacion
        fields = [
            "id", "tipo", "titulo", "mensaje", "entidad", "entidad_id",
            "leida", "fecha_creacion", "fecha_lectura",
        ]
        read_only_fields = fields