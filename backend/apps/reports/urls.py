from django.urls import path

from .views import ConstanciaPdfView, NotasExcelView

urlpatterns = [
    path("reportes/notas/", NotasExcelView.as_view(), name="reporte-notas"),
    path(
        "reportes/constancia/<int:resultado_id>/",
        ConstanciaPdfView.as_view(),
        name="reporte-constancia",
    ),
]