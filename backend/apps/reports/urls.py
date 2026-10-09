from django.urls import path

from .views import NotasExcelView

urlpatterns = [
    path("reportes/notas/", NotasExcelView.as_view(), name="reporte-notas"),
]