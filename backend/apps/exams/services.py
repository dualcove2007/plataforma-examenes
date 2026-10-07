from django.db import transaction
from django.db.models import Max
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.authentication.models import Rol, Usuario

from .models import AsignacionExamen, Examen, ExamenPregunta

E = Examen.Estado

TRANSICIONES = {
    E.BORRADOR: {E.PUBLICADO, E.ARCHIVADO},
    E.PUBLICADO: {E.CERRADO},
    E.CERRADO: {E.ARCHIVADO},
    E.ARCHIVADO: set(),
}


def exigir_borrador(examen):
    if examen.estado != E.BORRADOR:
        raise ValidationError("Solo se puede modificar un examen en borrador.")


def _validar_publicable(examen):
    if not examen.items.exists():
        raise ValidationError("El examen necesita al menos una pregunta.")
    if examen.fecha_fin <= timezone.now():
        raise ValidationError("La fecha de fin del examen ya pasó.")


@transaction.atomic
def cambiar_estado(examen, nuevo, usuario):
    # `usuario` se usará para registrar el historial de estados (etapa de auditoría)
    if nuevo not in TRANSICIONES[examen.estado]:
        raise ValidationError(f"No se puede pasar de '{examen.estado}' a '{nuevo}'.")
    if nuevo == E.PUBLICADO:
        _validar_publicable(examen)
    examen.estado = nuevo
    examen.save(update_fields=["estado"])
    return examen


def agregar_pregunta(examen, pregunta, puntaje=None):
    exigir_borrador(examen)
    if not pregunta.activo:
        raise ValidationError("La pregunta está inactiva.")
    if pregunta.banco.materia_id != examen.materia_id:
        raise ValidationError("La pregunta pertenece a otra materia.")
    if examen.items.filter(pregunta=pregunta).exists():
        raise ValidationError("La pregunta ya está en el examen.")
    orden = (examen.items.aggregate(m=Max("orden"))["m"] or 0) + 1
    return ExamenPregunta.objects.create(
        examen=examen,
        pregunta=pregunta,
        orden=orden,
        puntaje=puntaje if puntaje is not None else pregunta.puntaje,
    )


def quitar_pregunta(examen, pregunta_id):
    exigir_borrador(examen)
    eliminados, _ = examen.items.filter(pregunta_id=pregunta_id).delete()
    if not eliminados:
        raise ValidationError("La pregunta no está en el examen.")


@transaction.atomic
def asignar_estudiantes(examen, ids):
    if examen.estado not in (E.BORRADOR, E.PUBLICADO):
        raise ValidationError("Solo se asigna en exámenes en borrador o publicados.")
    ids = set(ids)
    validos = set(
        Usuario.objects.filter(
            id__in=ids, activo=True, rol__nombre=Rol.ESTUDIANTE
        ).values_list("id", flat=True)
    )
    invalidos = sorted(ids - validos)
    if invalidos:
        raise ValidationError(
            {"estudiantes": f"No son estudiantes activos: {invalidos}"}
        )
    existentes = set(
        AsignacionExamen.objects.filter(
            examen=examen, estudiante_id__in=validos
        ).values_list("estudiante_id", flat=True)
    )
    nuevos = validos - existentes
    AsignacionExamen.objects.bulk_create(
        [AsignacionExamen(examen=examen, estudiante_id=i) for i in nuevos]
    )
    return len(nuevos), len(existentes)