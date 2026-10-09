from django.db import transaction
from django.db.models import Q
from rest_framework.exceptions import PermissionDenied, ValidationError

from apps.audit.services import registrar
from apps.authentication.models import Rol
from apps.exams.models import AsignacionExamen, Examen

from .models import ArchivoAdjunto
from .validators import validar_archivo

E = Examen.Estado


def _es_admin(usuario):
    return usuario.rol.nombre == Rol.ADMINISTRADOR


def adjuntos_visibles(usuario):
    """Adjuntos que el usuario puede ver/descargar según su rol."""
    queryset = ArchivoAdjunto.objects.select_related("subido_por")
    if _es_admin(usuario):
        return queryset
    if usuario.rol.nombre == Rol.DOCENTE:
        return queryset.filter(
            Q(pregunta__banco__docente=usuario) | Q(examen__docente=usuario)
        )
    # Estudiante: solo lo de exámenes publicados que tiene asignados.
    examenes = AsignacionExamen.objects.filter(
        estudiante=usuario, examen__estado=E.PUBLICADO
    ).values("examen_id")
    return queryset.filter(
        Q(examen_id__in=examenes) | Q(pregunta__en_examenes__examen_id__in=examenes)
    ).distinct()


def _exigir_dueno(usuario, pregunta, examen):
    if _es_admin(usuario):
        return
    docente_id = pregunta.banco.docente_id if pregunta else examen.docente_id
    if docente_id != usuario.id:
        raise PermissionDenied("No puedes modificar los adjuntos de este elemento.")


def _exigir_editable(pregunta, examen):
    if examen is not None:
        if examen.estado != E.BORRADOR:
            raise ValidationError(
                "Solo se modifican los adjuntos de un examen en borrador."
            )
    elif pregunta.en_examenes.exclude(examen__estado=E.BORRADOR).exists():
        raise ValidationError(
            "La pregunta ya se usa en un examen publicado: "
            "no se pueden cambiar sus adjuntos."
        )


@transaction.atomic
def subir(usuario, archivo, pregunta=None, examen=None):
    if (pregunta is None) == (examen is None):
        raise ValidationError("Indica la pregunta o el examen (solo uno de los dos).")

    # Primero permisos y estado; recién después se inspecciona el archivo.
    _exigir_dueno(usuario, pregunta, examen)
    _exigir_editable(pregunta, examen)
    nombre, mime = validar_archivo(archivo)

    adjunto = ArchivoAdjunto(
        pregunta=pregunta,
        examen=examen,
        subido_por=usuario,
        nombre_original=nombre[:255],
        tipo_mime=mime,
        tamano=archivo.size,
    )
    adjunto.archivo.save(nombre, archivo, save=False)
    try:
        adjunto.save()
        registrar(
            "subir_adjunto",
            "ArchivoAdjunto",
            adjunto.pk,
            {
                "nombre": adjunto.nombre_original,
                "tamano": adjunto.tamano,
                "pregunta": pregunta.pk if pregunta else None,
                "examen": examen.pk if examen else None,
            },
            usuario,
        )
    except Exception:
        adjunto.archivo.delete(save=False)  # no dejar archivos huérfanos
        raise
    return adjunto


@transaction.atomic
def eliminar(usuario, adjunto):
    _exigir_dueno(usuario, adjunto.pregunta, adjunto.examen)
    _exigir_editable(adjunto.pregunta, adjunto.examen)

    almacenamiento, ruta = adjunto.archivo.storage, adjunto.archivo.name
    pk, nombre = adjunto.pk, adjunto.nombre_original
    adjunto.delete()
    registrar("eliminar_adjunto", "ArchivoAdjunto", pk, {"nombre": nombre}, usuario)
    # El archivo se borra del disco solo si la transacción se confirma.
    transaction.on_commit(lambda: almacenamiento.delete(ruta))