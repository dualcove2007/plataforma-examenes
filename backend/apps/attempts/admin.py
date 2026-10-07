from django.contrib import admin

from .models import Intento, RespuestaIntento, RespuestaOpcion, ResultadoExamen

admin.site.register(Intento)
admin.site.register(RespuestaIntento)
admin.site.register(RespuestaOpcion)
admin.site.register(ResultadoExamen)