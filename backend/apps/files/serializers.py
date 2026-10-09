from rest_framework import serializers

from apps.exams.models import Examen
from apps.question_banks.models import Pregunta

from .models import ArchivoAdjunto


class ArchivoAdjuntoSerializer(serializers.ModelSerializer):
    subido_por_nombre = serializers.CharField(source="subido_por.nombre", read_only=True)

    class Meta:
        model = ArchivoAdjunto
        fields = [
            "id", "pregunta", "examen", "nombre_original", "tipo_mime", "tamano",
            "subido_por", "subido_por_nombre", "fecha_creacion",
        ]
        read_only_fields = fields


class SubirAdjuntoSerializer(serializers.Serializer):
    archivo = serializers.FileField()
    pregunta = serializers.PrimaryKeyRelatedField(
        queryset=Pregunta.objects.select_related("banco"), required=False
    )
    examen = serializers.PrimaryKeyRelatedField(
        queryset=Examen.objects.all(), required=False
    )

    def validate(self, attrs):
        if ("pregunta" in attrs) == ("examen" in attrs):
            raise serializers.ValidationError(
                "Indica la pregunta o el examen (solo uno de los dos)."
            )
        return attrs