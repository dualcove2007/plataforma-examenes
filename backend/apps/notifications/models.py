from django.conf import settings
from django.db import models


class Notificacion(models.Model):
    class Tipo(models.TextChoices):
        EXAMEN_ASIGNADO = "examen_asignado", "Examen asignado"
        EXAMEN_PUBLICADO = "examen_publicado", "Examen publicado"
        RESULTADO_REVISADO = "resultado_revisado", "Resultado revisado"

    usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notificaciones",
    )
    tipo = models.CharField(max_length=30, choices=Tipo.choices)
    titulo = models.CharField(max_length=200)
    mensaje = models.CharField(max_length=500)
    # A qué apunta la notificación (para que el frontend navegue): Examen / Resultado
    entidad = models.CharField(max_length=50, blank=True)
    entidad_id = models.CharField(max_length=50, blank=True)
    leida = models.BooleanField(default=False)
    fecha_creacion = models.DateTimeField(auto_now_add=True)
    fecha_lectura = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "notificaciones"
        ordering = ["-fecha_creacion", "-id"]
        indexes = [models.Index(fields=["usuario", "leida"])]

    def __str__(self):
        return f"{self.usuario_id} · {self.tipo}"