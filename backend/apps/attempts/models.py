from django.conf import settings
from django.db import models
from django.db.models import Q
from django.utils import timezone


class Intento(models.Model):
    class Estado(models.TextChoices):
        EN_PROGRESO = "en_progreso", "En progreso"
        FINALIZADO = "finalizado", "Finalizado"
        EXPIRADO = "expirado", "Expirado"
        ANULADO = "anulado", "Anulado"

    asignacion = models.ForeignKey(
        "exams.AsignacionExamen", on_delete=models.PROTECT, related_name="intentos"
    )
    numero_intento = models.PositiveSmallIntegerField()
    fecha_inicio = models.DateTimeField(default=timezone.now)
    fecha_limite = models.DateTimeField()  # inicio + duración (sin pasar de fecha_fin)
    fecha_fin = models.DateTimeField(null=True, blank=True)
    estado = models.CharField(
        max_length=12, choices=Estado.choices, default=Estado.EN_PROGRESO
    )

    class Meta:
        db_table = "intentos"
        constraints = [
            models.UniqueConstraint(
                fields=["asignacion", "numero_intento"],
                name="uq_intento_asignacion_numero",
            ),
            # Un solo intento en progreso por asignación
            models.UniqueConstraint(
                fields=["asignacion"],
                condition=Q(estado="en_progreso"),
                name="uq_intento_en_progreso",
            ),
        ]


class RespuestaIntento(models.Model):
    intento = models.ForeignKey(
        Intento, on_delete=models.CASCADE, related_name="respuestas"
    )
    pregunta = models.ForeignKey(
        "question_banks.Pregunta", on_delete=models.PROTECT, related_name="respuestas"
    )
    texto_respuesta = models.TextField(blank=True)
    puntaje_obtenido = models.FloatField(null=True, blank=True)  # null = pendiente
    es_correcta = models.BooleanField(null=True, blank=True)
    fecha_respuesta = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = "respuestas_intento"
        constraints = [
            models.UniqueConstraint(
                fields=["intento", "pregunta"], name="uq_respuesta_intento_pregunta"
            )
        ]


class RespuestaOpcion(models.Model):
    respuesta = models.ForeignKey(
        RespuestaIntento, on_delete=models.CASCADE, related_name="seleccion"
    )
    opcion = models.ForeignKey(
        "question_banks.OpcionRespuesta", on_delete=models.PROTECT, related_name="+"
    )

    class Meta:
        db_table = "respuesta_opciones"
        constraints = [
            models.UniqueConstraint(
                fields=["respuesta", "opcion"], name="uq_respuesta_opcion"
            )
        ]


class ResultadoExamen(models.Model):
    class Revision(models.TextChoices):
        PENDIENTE = "pendiente", "Pendiente"
        EN_REVISION = "en_revision", "En revisión"
        REVISADO = "revisado", "Revisado"

    intento = models.OneToOneField(
        Intento, on_delete=models.CASCADE, related_name="resultado"
    )
    puntaje_total = models.FloatField(default=0)
    puntaje_maximo = models.FloatField(default=0)
    nota_final = models.FloatField(default=0)
    estado_revision = models.CharField(
        max_length=12, choices=Revision.choices, default=Revision.PENDIENTE
    )
    revisado_por = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name="revisiones",
    )
    fecha_revision = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "resultados_examen"
        


class EventoIntento(models.Model):
    """Señales de posible trampa registradas por el navegador durante un intento."""

    class Tipo(models.TextChoices):
        SALIDA_PESTANA = "salida_pestana", "Salió de la pestaña"
        PEGADO = "pegado", "Pegó texto"

    intento = models.ForeignKey(
        Intento, on_delete=models.CASCADE, related_name="eventos"
    )
    tipo = models.CharField(max_length=20, choices=Tipo.choices)
    fecha = models.DateTimeField(default=timezone.now)
    duracion_segundos = models.PositiveIntegerField(null=True, blank=True)

    class Meta:
        db_table = "eventos_intento"
        ordering = ["fecha", "id"]