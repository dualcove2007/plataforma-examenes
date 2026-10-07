from django.conf import settings
from django.db import models
from django.utils import timezone


def _fk_usuario(related):
    return models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.PROTECT,
        related_name=related,
    )


class Auditoria(models.Model):
    """Quién hizo qué, desde qué IP y cuándo."""

    usuario = _fk_usuario("auditorias")  # null = acción anónima (ej. login fallido)
    accion = models.CharField(max_length=50)  # crear, editar, eliminar, login, calificar...
    entidad = models.CharField(max_length=50)  # nombre del modelo: Examen, Pregunta...
    entidad_id = models.CharField(max_length=50, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    fecha = models.DateTimeField(default=timezone.now)
    detalle = models.JSONField(default=dict, blank=True)

    class Meta:
        db_table = "auditoria"
        ordering = ["-fecha", "-id"]
        indexes = [
            models.Index(fields=["entidad", "entidad_id"]),
            models.Index(fields=["usuario", "fecha"]),
            models.Index(fields=["accion"]),
        ]


class HistorialCambios(models.Model):
    """Un registro por cada campo que cambió en un modelo importante."""

    entidad = models.CharField(max_length=50)
    entidad_id = models.CharField(max_length=50)
    campo = models.CharField(max_length=100)
    valor_anterior = models.TextField(blank=True, null=True)
    valor_nuevo = models.TextField(blank=True, null=True)
    usuario = _fk_usuario("cambios")
    fecha = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = "historial_cambios"
        ordering = ["-fecha", "-id"]
        indexes = [models.Index(fields=["entidad", "entidad_id"])]


class HistorialEstado(models.Model):
    """Transiciones de estado: examen, intento, revisión del resultado."""

    entidad = models.CharField(max_length=50)
    entidad_id = models.CharField(max_length=50)
    estado_anterior = models.CharField(max_length=30, blank=True)
    estado_nuevo = models.CharField(max_length=30)
    usuario = _fk_usuario("cambios_estado")  # null = lo hizo el sistema (Celery, expiración)
    fecha = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = "historial_estado"
        ordering = ["-fecha", "-id"]
        indexes = [models.Index(fields=["entidad", "entidad_id"])]