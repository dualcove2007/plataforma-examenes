import uuid
from pathlib import Path

from django.conf import settings
from django.db import models
from django.db.models import Q


def ruta_adjunto(instancia, nombre_original):
    """Guarda con un nombre generado (uuid): nunca se confía en el nombre del cliente."""
    extension = Path(nombre_original).suffix.lower()
    if instancia.pregunta_id:
        carpeta = f"preguntas/{instancia.pregunta_id}"
    else:
        carpeta = f"examenes/{instancia.examen_id}"
    return f"adjuntos/{carpeta}/{uuid.uuid4().hex}{extension}"


class ArchivoAdjunto(models.Model):
    pregunta = models.ForeignKey(
        "question_banks.Pregunta",
        on_delete=models.CASCADE,
        related_name="adjuntos",
        null=True,
        blank=True,
    )
    examen = models.ForeignKey(
        "exams.Examen",
        on_delete=models.CASCADE,
        related_name="adjuntos",
        null=True,
        blank=True,
    )
    subido_por = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="archivos_subidos",
    )
    archivo = models.FileField(upload_to=ruta_adjunto, max_length=255)
    nombre_original = models.CharField(max_length=255)
    tipo_mime = models.CharField(max_length=100)
    tamano = models.PositiveIntegerField(help_text="Tamaño en bytes")
    fecha_creacion = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "archivos_adjuntos"
        ordering = ["-fecha_creacion", "-id"]
        constraints = [
            # Un adjunto pertenece a una pregunta O a un examen, nunca a ambos ni a ninguno.
            models.CheckConstraint(
                condition=(
                    Q(pregunta__isnull=False, examen__isnull=True)
                    | Q(pregunta__isnull=True, examen__isnull=False)
                ),
                name="ck_adjunto_un_solo_dueno",
            )
        ]

    def __str__(self):
        return self.nombre_original