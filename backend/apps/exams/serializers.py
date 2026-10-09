from rest_framework import serializers
from apps.authentication.models import Usuario
from apps.question_banks.models import Pregunta
from apps.question_banks.serializers import OpcionSerializer

from .models import AsignacionExamen, Examen, ExamenPregunta


class ExamenSerializer(serializers.ModelSerializer):
    materia_nombre = serializers.CharField(source="materia.nombre", read_only=True)
    total_preguntas = serializers.IntegerField(read_only=True)
    puntaje_total = serializers.FloatField(read_only=True)

    class Meta:
        model = Examen
        fields = [
            "id", "materia", "materia_nombre", "titulo", "descripcion",
            "fecha_inicio", "fecha_fin", "duracion_minutos", "intentos_permitidos",
            "estado", "docente", "fecha_creacion", "total_preguntas", "puntaje_total",
        ]
        read_only_fields = ["estado", "docente", "fecha_creacion"]

    def validate_duracion_minutos(self, value):
        if not 1 <= value <= 600:
            raise serializers.ValidationError("La duración debe estar entre 1 y 600 minutos.")
        return value

    def validate_intentos_permitidos(self, value):
        if not 1 <= value <= 10:
            raise serializers.ValidationError("Los intentos deben estar entre 1 y 10.")
        return value

    def validate(self, attrs):
        inicio = attrs.get("fecha_inicio", getattr(self.instance, "fecha_inicio", None))
        fin = attrs.get("fecha_fin", getattr(self.instance, "fecha_fin", None))
        if inicio and fin and fin <= inicio:
            raise serializers.ValidationError(
                {"fecha_fin": "La fecha de fin debe ser posterior a la de inicio."}
            )
        return attrs


class ExamenPreguntaSerializer(serializers.ModelSerializer):
    enunciado = serializers.CharField(source="pregunta.enunciado", read_only=True)
    tipo = serializers.CharField(source="pregunta.tipo", read_only=True)
    dificultad = serializers.CharField(source="pregunta.dificultad", read_only=True)
    opciones = OpcionSerializer(source="pregunta.opciones", many=True, read_only=True)

    class Meta:
        model = ExamenPregunta
        fields = [
            "id", "pregunta", "orden", "puntaje",
            "enunciado", "tipo", "dificultad", "opciones",
        ]


class ExamenDetalleSerializer(ExamenSerializer):
    preguntas = ExamenPreguntaSerializer(source="items", many=True, read_only=True)

    class Meta(ExamenSerializer.Meta):
        fields = ExamenSerializer.Meta.fields + ["preguntas"]


class AgregarPreguntaSerializer(serializers.Serializer):
    pregunta = serializers.PrimaryKeyRelatedField(queryset=Pregunta.objects.all())
    puntaje = serializers.FloatField(required=False, min_value=0.01)

    def validate_pregunta(self, pregunta):
        if pregunta.banco.docente_id != self.context["request"].user.id:
            raise serializers.ValidationError("No puedes usar preguntas de otro docente.")
        return pregunta


class QuitarPreguntaSerializer(serializers.Serializer):
    pregunta = serializers.IntegerField()


class AsignarSerializer(serializers.Serializer):
    estudiantes = serializers.ListField(
        child=serializers.IntegerField(), allow_empty=False, max_length=200
    )


class AsignacionSerializer(serializers.ModelSerializer):
    estudiante_nombre = serializers.CharField(source="estudiante.nombre", read_only=True)
    estudiante_email = serializers.CharField(source="estudiante.email", read_only=True)

    class Meta:
        model = AsignacionExamen
        fields = [
            "id", "estudiante", "estudiante_nombre", "estudiante_email",
            "fecha_asignacion", "estado",
        ]


class MiExamenSerializer(serializers.ModelSerializer):
    titulo = serializers.CharField(source="examen.titulo", read_only=True)
    materia = serializers.CharField(source="examen.materia.nombre", read_only=True)
    fecha_inicio = serializers.DateTimeField(source="examen.fecha_inicio", read_only=True)
    fecha_fin = serializers.DateTimeField(source="examen.fecha_fin", read_only=True)
    duracion_minutos = serializers.IntegerField(source="examen.duracion_minutos", read_only=True)
    intentos_permitidos = serializers.IntegerField(source="examen.intentos_permitidos", read_only=True)
    examen_estado = serializers.CharField(source="examen.estado", read_only=True)
    total_preguntas = serializers.IntegerField(read_only=True)

    class Meta:
        model = AsignacionExamen
        fields = [
            "id", "examen", "titulo", "materia", "fecha_inicio", "fecha_fin",
            "duracion_minutos", "intentos_permitidos", "examen_estado",
            "estado", "total_preguntas",
        ]
        

class EstudianteSerializer(serializers.ModelSerializer):
    class Meta:
        model = Usuario
        fields = ["id", "nombre", "email"]