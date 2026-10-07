from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from apps.exams.models import ExamenPregunta
from apps.question_banks.models import OpcionRespuesta

from .models import Intento, RespuestaIntento, ResultadoExamen
from .services import segundos_restantes


class IniciarSerializer(serializers.Serializer):
    asignacion = serializers.IntegerField()


class ResponderSerializer(serializers.Serializer):
    pregunta = serializers.IntegerField()
    opciones = serializers.ListField(
        child=serializers.IntegerField(), required=False, default=list
    )
    texto_respuesta = serializers.CharField(
        required=False, allow_blank=True, default="", max_length=5000
    )


class CalificacionSerializer(serializers.Serializer):
    respuesta = serializers.IntegerField()
    puntaje = serializers.FloatField(min_value=0)


class CalificarSerializer(serializers.Serializer):
    calificaciones = CalificacionSerializer(many=True, allow_empty=False)


# ---------- Vista del estudiante: NUNCA incluye es_correcta ----------
class OpcionEstudianteSerializer(serializers.ModelSerializer):
    class Meta:
        model = OpcionRespuesta
        fields = ["id", "texto"]


class PreguntaEstudianteSerializer(serializers.ModelSerializer):
    pregunta = serializers.IntegerField(source="pregunta_id", read_only=True)
    enunciado = serializers.CharField(source="pregunta.enunciado", read_only=True)
    tipo = serializers.CharField(source="pregunta.tipo", read_only=True)
    opciones = OpcionEstudianteSerializer(
        source="pregunta.opciones", many=True, read_only=True
    )
    respuesta = serializers.SerializerMethodField()

    class Meta:
        model = ExamenPregunta
        fields = ["pregunta", "orden", "puntaje", "enunciado", "tipo", "opciones", "respuesta"]
        read_only_fields = ["orden", "puntaje"]

    def get_respuesta(self, item) -> dict:
        r = self.context["respuestas"].get(item.pregunta_id)
        if r is None:
            return None
        return {
            "texto_respuesta": r.texto_respuesta,
            "opciones": [s.opcion_id for s in r.seleccion.all()],
        }


class IntentoSerializer(serializers.ModelSerializer):
    examen = serializers.IntegerField(source="asignacion.examen_id", read_only=True)
    titulo = serializers.CharField(source="asignacion.examen.titulo", read_only=True)
    segundos_restantes = serializers.SerializerMethodField()

    class Meta:
        model = Intento
        fields = [
            "id", "asignacion", "examen", "titulo", "numero_intento", "estado",
            "fecha_inicio", "fecha_limite", "fecha_fin", "segundos_restantes",
        ]
        read_only_fields = fields

    def get_segundos_restantes(self, obj) -> int:
        return segundos_restantes(obj)


class IntentoDetalleSerializer(IntentoSerializer):
    preguntas = serializers.SerializerMethodField()

    class Meta(IntentoSerializer.Meta):
        fields = IntentoSerializer.Meta.fields + ["preguntas"]
        read_only_fields = fields

    @extend_schema_field(PreguntaEstudianteSerializer(many=True))
    def get_preguntas(self, obj):
        items = obj.asignacion.examen.items.select_related(
            "pregunta"
        ).prefetch_related("pregunta__opciones")
        respuestas = {
            r.pregunta_id: r for r in obj.respuestas.prefetch_related("seleccion")
        }
        return PreguntaEstudianteSerializer(
            items, many=True, context={"respuestas": respuestas}
        ).data


# ---------- Resultados ----------
class ResultadoSerializer(serializers.ModelSerializer):
    estudiante = serializers.CharField(
        source="intento.asignacion.estudiante.nombre", read_only=True
    )
    estudiante_email = serializers.CharField(
        source="intento.asignacion.estudiante.email", read_only=True
    )
    examen = serializers.IntegerField(
        source="intento.asignacion.examen_id", read_only=True
    )
    examen_titulo = serializers.CharField(
        source="intento.asignacion.examen.titulo", read_only=True
    )
    numero_intento = serializers.IntegerField(
        source="intento.numero_intento", read_only=True
    )
    intento_estado = serializers.CharField(source="intento.estado", read_only=True)

    class Meta:
        model = ResultadoExamen
        fields = [
            "id", "intento", "examen", "examen_titulo", "estudiante",
            "estudiante_email", "numero_intento", "intento_estado",
            "puntaje_total", "puntaje_maximo", "nota_final",
            "estado_revision", "revisado_por", "fecha_revision",
        ]
        read_only_fields = fields

    def to_representation(self, instance):
        data = super().to_representation(instance)
        # Al estudiante no se le muestra una nota provisional
        if (
            self.context.get("es_estudiante")
            and instance.estado_revision != ResultadoExamen.Revision.REVISADO
        ):
            data["puntaje_total"] = None
            data["nota_final"] = None
        return data


class RespuestaDetalleSerializer(serializers.ModelSerializer):
    enunciado = serializers.CharField(source="pregunta.enunciado", read_only=True)
    tipo = serializers.CharField(source="pregunta.tipo", read_only=True)
    puntaje_maximo = serializers.SerializerMethodField()
    opciones_seleccionadas = serializers.SerializerMethodField()

    class Meta:
        model = RespuestaIntento
        fields = [
            "id", "pregunta", "enunciado", "tipo", "puntaje_maximo",
            "texto_respuesta", "opciones_seleccionadas",
            "puntaje_obtenido", "es_correcta",
        ]

    def get_puntaje_maximo(self, obj) -> float:
        return self.context.get("maximos", {}).get(obj.pregunta_id)

    def get_opciones_seleccionadas(self, obj) -> list:
        return [{"id": s.opcion_id, "texto": s.opcion.texto} for s in obj.seleccion.all()]


class ResultadoDetalleSerializer(ResultadoSerializer):
    respuestas = serializers.SerializerMethodField()

    class Meta(ResultadoSerializer.Meta):
        fields = ResultadoSerializer.Meta.fields + ["respuestas"]
        read_only_fields = fields

    @extend_schema_field(RespuestaDetalleSerializer(many=True))
    def get_respuestas(self, obj):
        respuestas = (
            obj.intento.respuestas.select_related("pregunta")
            .prefetch_related("seleccion__opcion")
            .order_by("id")
        )
        return RespuestaDetalleSerializer(
            respuestas, many=True, context=self.context
        ).data