from django.http import HttpResponse
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from apps.attempts.models import ResultadoExamen
from apps.audit.services import registrar
from apps.authentication.models import Rol
from apps.authentication.permissions import tiene_permiso
from apps.exams.models import Examen

from . import services
from .pdf import generar_constancia_pdf

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


class ConstanciaPdfView(APIView):
    """Constancia en PDF de un resultado propio ya revisado."""

    permission_classes = [IsAuthenticated, tiene_permiso("resultados.ver_propios")]

    @extend_schema(responses={(200, "application/pdf"): OpenApiTypes.BINARY})
    def get(self, request, resultado_id):
        resultado = (
            ResultadoExamen.objects.select_related(
                "intento__asignacion__examen__materia",
                "intento__asignacion__estudiante",
                "revisado_por",
            )
            .filter(pk=resultado_id, intento__asignacion__estudiante=request.user)
            .first()
        )
        if resultado is None:
            raise NotFound("No existe ese resultado.")
        if resultado.estado_revision != ResultadoExamen.Revision.REVISADO:
            raise ValidationError("El resultado aún no ha sido revisado.")

        contenido = generar_constancia_pdf(resultado)
        registrar("exportar", "Resultado", resultado.pk, {"reporte": "constancia"})

        respuesta = HttpResponse(contenido, content_type="application/pdf")
        respuesta["Content-Disposition"] = (
            f'attachment; filename="constancia_resultado_{resultado.pk}.pdf"'
        )
        return respuesta