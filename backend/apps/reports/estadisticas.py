from django.conf import settings
from django.db.models import Avg, Count, Q

from apps.attempts.models import Intento, ResultadoExamen
from apps.authentication.models import Rol
from apps.exams.models import AsignacionExamen, Examen

REVISADO = ResultadoExamen.Revision.REVISADO
MAX_EXAMENES = 10  # cuántos exámenes recientes se detallan en "por_examen"


def _agregados():
    """Métricas sobre resultados REVISADOS (los provisionales no cuentan)."""
    revisado = Q(estado_revision=REVISADO)
    minima = settings.NOTA_APROBATORIA
    return {
        "revisados": Count("id", filter=revisado),
        "promedio": Avg("nota_final", filter=revisado),
        "aprobados": Count("id", filter=revisado & Q(nota_final__gte=minima)),
        "reprobados": Count("id", filter=revisado & Q(nota_final__lt=minima)),
    }


def _redondear(valor):
    return None if valor is None else round(valor, 1)


def _tasa(aprobados, revisados):
    return round(aprobados / revisados * 100, 1) if revisados else None


def estadisticas(usuario, examen_id=None):
    """Métricas del dashboard. El docente solo ve las de sus exámenes."""
    examenes = Examen.objects.all()
    if usuario.rol.nombre != Rol.ADMINISTRADOR:
        examenes = examenes.filter(docente=usuario)
    if examen_id is not None:
        examenes = examenes.filter(pk=examen_id)

    por_estado = dict(examenes.values_list("estado").annotate(n=Count("id")))
    estados = {e.value: por_estado.get(e.value, 0) for e in Examen.Estado}
    estados["total"] = sum(estados.values())

    intentos = Intento.objects.filter(asignacion__examen__in=examenes).aggregate(
        total=Count("id"),
        **{e.value: Count("id", filter=Q(estado=e.value)) for e in Intento.Estado},
    )

    resultados_qs = ResultadoExamen.objects.filter(
        intento__asignacion__examen__in=examenes
    ).exclude(intento__estado=Intento.Estado.ANULADO)
    res = resultados_qs.aggregate(total=Count("id"), **_agregados())

    # Detalle de los exámenes más recientes
    recientes = list(
        examenes.order_by("-fecha_creacion").values("id", "titulo", "estado")[
            :MAX_EXAMENES
        ]
    )
    ids = [e["id"] for e in recientes]
    asignados = dict(
        AsignacionExamen.objects.filter(examen_id__in=ids)
        .values_list("examen_id")
        .annotate(n=Count("id"))
    )
    filas = {
        f["intento__asignacion__examen_id"]: f
        for f in resultados_qs.filter(intento__asignacion__examen_id__in=ids)
        .values("intento__asignacion__examen_id")
        .annotate(
            presentaron=Count("intento__asignacion", distinct=True), **_agregados()
        )
    }
    por_examen = []
    for e in recientes:
        f = filas.get(e["id"], {})
        por_examen.append(
            {
                "id": e["id"],
                "titulo": e["titulo"],
                "estado": e["estado"],
                "asignados": asignados.get(e["id"], 0),
                "presentaron": f.get("presentaron", 0),
                "revisados": f.get("revisados", 0),
                "promedio_nota": _redondear(f.get("promedio")),
                "aprobados": f.get("aprobados", 0),
                "reprobados": f.get("reprobados", 0),
            }
        )

    return {
        "nota_minima": settings.NOTA_APROBATORIA,
        "examenes": estados,
        "asignaciones": AsignacionExamen.objects.filter(examen__in=examenes).count(),
        "intentos": intentos,
        "resultados": {
            "total": res["total"],
            "revisados": res["revisados"],
            "pendientes_revision": res["total"] - res["revisados"],
            "promedio_nota": _redondear(res["promedio"]),
            "aprobados": res["aprobados"],
            "reprobados": res["reprobados"],
            "tasa_aprobacion": _tasa(res["aprobados"], res["revisados"]),
        },
        "por_examen": por_examen,
    }