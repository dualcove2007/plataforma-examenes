from django.contrib import admin

from .models import AsignacionExamen, Examen, ExamenPregunta

admin.site.register(Examen)
admin.site.register(ExamenPregunta)
admin.site.register(AsignacionExamen)