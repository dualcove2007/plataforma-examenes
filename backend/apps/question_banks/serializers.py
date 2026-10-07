from django.db import transaction
from rest_framework import serializers

from .models import BancoPreguntas, Materia, OpcionRespuesta, Pregunta


class MateriaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Materia
        fields = ["id", "nombre", "descripcion"]


class BancoSerializer(serializers.ModelSerializer):
    materia_nombre = serializers.CharField(source="materia.nombre", read_only=True)
    docente_nombre = serializers.CharField(source="docente.nombre", read_only=True)
    total_preguntas = serializers.IntegerField(read_only=True)

    class Meta:
        model = BancoPreguntas
        fields = [
            "id", "materia", "materia_nombre", "docente", "docente_nombre",
            "titulo", "descripcion", "activo", "fecha_creacion", "total_preguntas",
        ]
        read_only_fields = ["docente", "fecha_creacion"]


class OpcionSerializer(serializers.ModelSerializer):
    class Meta:
        model = OpcionRespuesta
        fields = ["id", "texto", "es_correcta"]
        read_only_fields = ["id"]


class PreguntaSerializer(serializers.ModelSerializer):
    opciones = OpcionSerializer(many=True, required=False)

    class Meta:
        model = Pregunta
        fields = [
            "id", "banco", "enunciado", "tipo", "dificultad",
            "puntaje", "activo", "opciones",
        ]

    def validate_banco(self, banco):
        request = self.context["request"]
        if banco.docente_id != request.user.id:
            raise serializers.ValidationError("No puedes usar un banco de otro docente.")
        if not banco.activo:
            raise serializers.ValidationError("El banco está inactivo.")
        return banco

    def validate_puntaje(self, value):
        if value <= 0:
            raise serializers.ValidationError("El puntaje debe ser mayor que 0.")
        return value

    def validate(self, attrs):
        tipo = attrs.get("tipo", self.instance.tipo if self.instance else None)
        opciones = attrs.get("opciones")
        if opciones is None:
            if self.instance is None:
                opciones = []
            elif "tipo" in attrs and attrs["tipo"] != self.instance.tipo:
                raise serializers.ValidationError(
                    {"opciones": "Si cambias el tipo, envía también las opciones."}
                )
            else:
                return attrs
        self._validar_opciones(tipo, opciones)
        return attrs

    @staticmethod
    def _validar_opciones(tipo, opciones):
        total = len(opciones)
        correctas = sum(1 for o in opciones if o.get("es_correcta"))
        T = Pregunta.Tipo
        mensaje = None
        if tipo == T.ABIERTA:
            if total:
                mensaje = "Las preguntas abiertas no llevan opciones."
        elif tipo == T.VERDADERO_FALSO:
            if total != 2 or correctas != 1:
                mensaje = "Verdadero o falso lleva exactamente 2 opciones y 1 correcta."
        elif tipo == T.OPCION_UNICA:
            if total < 2 or correctas != 1:
                mensaje = "Opción única lleva al menos 2 opciones y exactamente 1 correcta."
        elif tipo == T.OPCION_MULTIPLE:
            if total < 2 or correctas < 1:
                mensaje = "Opción múltiple lleva al menos 2 opciones y 1 o más correctas."
        if mensaje:
            raise serializers.ValidationError({"opciones": mensaje})

    @transaction.atomic
    def create(self, validated_data):
        opciones = validated_data.pop("opciones", [])
        pregunta = Pregunta.objects.create(**validated_data)
        OpcionRespuesta.objects.bulk_create(
            [OpcionRespuesta(pregunta=pregunta, **o) for o in opciones]
        )
        return pregunta

    @transaction.atomic
    def update(self, instance, validated_data):
        opciones = validated_data.pop("opciones", None)
        for campo, valor in validated_data.items():
            setattr(instance, campo, valor)
        instance.save()
        if opciones is not None:
            instance.opciones.all().delete()
            OpcionRespuesta.objects.bulk_create(
                [OpcionRespuesta(pregunta=instance, **o) for o in opciones]
            )
        return instance