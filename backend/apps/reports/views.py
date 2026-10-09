from django.http import HttpResponse
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from apps.audit.services import registrar
from apps.authentication.models import Rol
from apps.authentication.permissions import tiene_permiso
from apps.exams.models import Examen

from . import services

XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


class NotasExcelView(APIView):
    """Excel con las notas de un examen (el docente solo ve los suyos)."""

    permission_classes = [IsAuthenticated, tiene_permiso("reportes.ver")]

    @extend_schema(
        parameters=[OpenApiParameter("examen", int, required=True)],
        responses={(200, XLSX): OpenApiTypes.BINARY},
    )
    def get(self, request):
        try:
            examen_id = int(request.query_params.get("examen", ""))
        except ValueError:
            raise ValidationError({"examen": "Indica el id del examen (?examen=<id>)."})

        examenes = Examen.objects.select_related("materia")
        if request.user.rol.nombre != Rol.ADMINISTRADOR:
            examenes = examenes.filter(docente=request.user)
        examen = examenes.filter(pk=examen_id).first()
        if examen is None:
            raise NotFound("No existe ese examen.")

        contenido = services.generar_excel_notas(examen)
        registrar("exportar", "Examen", examen.pk, {"reporte": "notas"})

        respuesta = HttpResponse(contenido, content_type=XLSX)
        respuesta["Content-Disposition"] = (
            f'attachment; filename="notas_examen_{examen.pk}.xlsx"'
        )
        return respuesta