from django.conf import settings
from django.db import models


class Materia(models.Model):
    nombre = models.CharField(max_length=150, unique=True)
    descripcion = models.CharField(max_length=255, blank=True)

    class Meta:
        db_table = "materias"
        ordering = ["nombre"]

    def __str__(self):
        return self.nombre


class BancoPreguntas(models.Model):
    materia = models.ForeignKey(
        Materia, on_delete=models.PROTECT, related_name="bancos"
    )
    docente = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="bancos"
    )
    titulo = models.CharField(max_length=200)
    descripcion = models.CharField(max_length=255, blank=True)
    activo = models.BooleanField(default=True)
    fecha_creacion = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "bancos_preguntas"

    def __str__(self):
        return self.titulo


class Pregunta(models.Model):
    class Tipo(models.TextChoices):
        OPCION_UNICA = "opcion_unica", "Opción única"
        OPCION_MULTIPLE = "opcion_multiple", "Opción múltiple"
        VERDADERO_FALSO = "verdadero_falso", "Verdadero o falso"
        ABIERTA = "abierta", "Abierta"

    class Dificultad(models.TextChoices):
        FACIL = "facil", "Fácil"
        MEDIA = "media", "Media"
        DIFICIL = "dificil", "Difícil"

    banco = models.ForeignKey(
        BancoPreguntas, on_delete=models.PROTECT, related_name="preguntas"
    )
    enunciado = models.TextField()
    tipo = models.CharField(max_length=20, choices=Tipo.choices)
    dificultad = models.CharField(
        max_length=10, choices=Dificultad.choices, default=Dificultad.MEDIA
    )
    puntaje = models.FloatField(default=1.0)
    activo = models.BooleanField(default=True)

    class Meta:
        db_table = "preguntas"

    def __str__(self):
        return self.enunciado[:60]


class OpcionRespuesta(models.Model):
    pregunta = models.ForeignKey(
        Pregunta, on_delete=models.CASCADE, related_name="opciones"
    )
    texto = models.CharField(max_length=500)
    es_correcta = models.BooleanField(default=False)

    class Meta:
        db_table = "opciones_respuesta"