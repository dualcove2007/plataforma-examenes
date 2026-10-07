from django.contrib import admin

from .models import BancoPreguntas, Materia, OpcionRespuesta, Pregunta

admin.site.register(Materia)
admin.site.register(BancoPreguntas)
admin.site.register(Pregunta)
admin.site.register(OpcionRespuesta)