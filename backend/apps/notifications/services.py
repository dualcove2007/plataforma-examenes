from django.utils import timezone

from .models import Notificacion

T = Notificacion.Tipo


def crear_para(usuarios_ids, tipo, titulo, mensaje, entidad="", entidad_id=""):
    """Crea la misma notificación para varios usuarios en una sola consulta."""
    ids = set(usuarios_ids)
    if not ids:
        return 0
    Notificacion.objects.bulk_create(
        [
            Notificacion(
                usuario_id=i,
                tipo=tipo,
                titulo=titulo,
                mensaje=mensaje,
                entidad=entidad,
                entidad_id=str(entidad_id),
            )
            for i in ids
        ]
    )
    return len(ids)


def notificar_asignacion(examen, estudiantes_ids):
    """Estudiantes asignados a un examen que YA está publicado."""
    return crear_para(
        estudiantes_ids,
        T.EXAMEN_ASIGNADO,
        "Nuevo examen asignado",
        f"Te asignaron el examen «{examen.titulo}».",
        "Examen",
        examen.pk,
    )


def notificar_publicacion(examen):
    """Al publicar: avisa a todos los estudiantes que ya estaban asignados."""
    ids = examen.asignaciones.values_list("estudiante_id", flat=True)
    return crear_para(
        ids,
        T.EXAMEN_PUBLICADO,
        "Examen disponible",
        f"El examen «{examen.titulo}» ya está publicado.",
        "Examen",
        examen.pk,
    )


def notificar_resultado_revisado(resultado):
    """No incluye la nota: el estudiante la consulta en su resultado."""
    asignacion = resultado.intento.asignacion
    return crear_para(
        [asignacion.estudiante_id],
        T.RESULTADO_REVISADO,
        "Resultado disponible",
        f"Tu resultado del examen «{asignacion.examen.titulo}» ya fue revisado.",
        "Resultado",
        resultado.pk,
    )


def marcar_leida(notificacion):
    if not notificacion.leida:
        notificacion.leida = True
        notificacion.fecha_lectura = timezone.now()
        notificacion.save(update_fields=["leida", "fecha_lectura"])
    return notificacion


def marcar_todas(usuario):
    return Notificacion.objects.filter(usuario=usuario, leida=False).update(
        leida=True, fecha_lectura=timezone.now()
    )


def contar_no_leidas(usuario):
    return Notificacion.objects.filter(usuario=usuario, leida=False).count()



def eliminar_leidas(usuario):
    eliminadas, _ = Notificacion.objects.filter(usuario=usuario, leida=True).delete()
    return eliminadas