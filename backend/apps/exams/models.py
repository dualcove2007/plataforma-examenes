from django.conf import settings
from django.db import models
from django.db.models import F, Q


class Examen(models.Model):
    class Estado(models.TextChoices):
        BORRADOR = "borrador", "Borrador"
        PUBLICADO = "publicado", "Publicado"
        CERRADO = "cerrado", "Cerrado"
        ARCHIVADO = "archivado", "Archivado"

    docente = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="examenes"
    )
    materia = models.ForeignKey(
        "question_banks.Materia", on_delete=models.PROTECT, related_name="examenes"
    )
    titulo = models.CharField(max_length=200)
    descripcion = models.TextField(blank=True)
    fecha_inicio = models.DateTimeField()
    fecha_fin = models.DateTimeField()
    duracion_minutos = models.PositiveIntegerField()
    intentos_permitidos = models.PositiveSmallIntegerField(default=1)
    estado = models.CharField(
        max_length=10, choices=Estado.choices, default=Estado.BORRADOR
    )
    fecha_creacion = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "examenes"
        constraints = [
            models.CheckConstraint(
                condition=Q(fecha_fin__gt=F("fecha_inicio")), name="ck_examen_fechas"
            )
        ]

    def __str__(self):
        return self.titulo


class ExamenPregunta(models.Model):
    examen = models.ForeignKey(Examen, on_delete=models.CASCADE, related_name="items")
    pregunta = models.ForeignKey(
        "question_banks.Pregunta", on_delete=models.PROTECT, related_name="en_examenes"
    )
    orden = models.PositiveIntegerField()
    puntaje = models.FloatField()  # puntaje de la pregunta en ESTE examen

    class Meta:
        db_table = "examen_preguntas"
        ordering = ["orden"]
        constraints = [
            models.UniqueConstraint(
                fields=["examen", "pregunta"], name="uq_examen_pregunta"
            )
        ]


class AsignacionExamen(models.Model):
    class Estado(models.TextChoices):
        PENDIENTE = "pendiente", "Pendiente"
        EN_PROGRESO = "en_progreso", "En progreso"
        COMPLETADO = "completado", "Completado"
        VENCIDO = "vencido", "Vencido"

    examen = models.ForeignKey(
        Examen, on_delete=models.CASCADE, related_name="asignaciones"
    )
    estudiante = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="asignaciones"
    )
    fecha_asignacion = models.DateTimeField(auto_now_add=True)
    estado = models.CharField(
        max_length=12, choices=Estado.choices, default=Estado.PENDIENTE
    )

    class Meta:
        db_table = "asignaciones_examen"
        constraints = [
            models.UniqueConstraint(
                fields=["examen", "estudiante"], name="uq_asignacion_examen_estudiante"
            )
        ]