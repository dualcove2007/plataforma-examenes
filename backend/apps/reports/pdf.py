from io import BytesIO
from xml.sax.saxutils import escape

from django.conf import settings
from django.utils import timezone
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


def _fecha(valor):
    if valor is None:
        return "—"
    return timezone.localtime(valor).strftime("%d/%m/%Y %H:%M")


def generar_constancia_pdf(resultado):
    """Devuelve los bytes de la constancia de un resultado ya revisado."""
    intento = resultado.intento
    examen = intento.asignacion.examen
    estudiante = intento.asignacion.estudiante
    aprobado = resultado.nota_final >= settings.NOTA_APROBATORIA

    estilos = getSampleStyleSheet()
    titulo = ParagraphStyle(
        "Titulo", parent=estilos["Title"], fontSize=20, spaceAfter=18
    )
    cuerpo = ParagraphStyle(
        "Cuerpo", parent=estilos["BodyText"], fontSize=11, leading=16, spaceAfter=14
    )
    pie = ParagraphStyle(
        "Pie", parent=estilos["BodyText"], fontSize=8, textColor=colors.grey
    )

    revisor = resultado.revisado_por.nombre if resultado.revisado_por else "Sistema"
    filas = [
        ["Examen", examen.titulo],
        ["Materia", examen.materia.nombre],
        ["Intento", str(intento.numero_intento)],
        ["Fecha de envío", _fecha(intento.fecha_fin)],
        ["Puntaje", f"{resultado.puntaje_total:g} / {resultado.puntaje_maximo:g}"],
        ["Nota final", f"{resultado.nota_final:.1f} / 5.0"],
        ["Resultado", "Aprobado" if aprobado else "Reprobado"],
        ["Revisado por", revisor],
    ]
    datos = [[Paragraph(f"<b>{a}</b>", cuerpo), Paragraph(escape(b), cuerpo)] for a, b in filas]
    tabla = Table(datos, colWidths=[4.5 * cm, 11.5 * cm])
    tabla.setStyle(
        TableStyle(
            [
                ("GRID", (0, 0), (-1, -1), 0.5, colors.lightgrey),
                ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#EEF2FA")),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ]
        )
    )

    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        title=f"Constancia - {examen.titulo}",
        author="Plataforma de Exámenes en Línea",
        leftMargin=2.5 * cm,
        rightMargin=2.5 * cm,
        topMargin=2.5 * cm,
        bottomMargin=2.5 * cm,
    )
    doc.build(
        [
            Paragraph("Constancia de resultado", titulo),
            Paragraph(
                f"Se certifica que <b>{escape(estudiante.nombre)}</b> "
                f"({escape(estudiante.email)}) presentó el examen "
                f"«{escape(examen.titulo)}» y obtuvo el siguiente resultado:",
                cuerpo,
            ),
            Spacer(1, 6),
            tabla,
            Spacer(1, 24),
            Paragraph(
                f"Documento generado el {_fecha(timezone.now())} por la "
                "Plataforma de Exámenes en Línea.",
                pie,
            ),
        ]
    )
    return buffer.getvalue()