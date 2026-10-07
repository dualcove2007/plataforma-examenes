from django.apps import apps
from django.db.models.signals import m2m_changed, post_delete, post_save, pre_save

from . import context
from .models import HistorialCambios
from .services import registrar

MODELOS = [
    "authentication.Usuario",
    "authentication.Rol",
    "question_banks.Materia",
    "question_banks.BancoPreguntas",
    "question_banks.Pregunta",
    "exams.Examen",
    "exams.ExamenPregunta",
    "attempts.ResultadoExamen",
]
# Los estados van a HistorialEstado; el resto se excluye por ruido o por sensible.
EXCLUIDOS = {"password", "last_login", "estado", "estado_revision"}


def _texto(valor):
    return None if valor is None else str(valor)[:500]


def _antes(sender, instance, raw=False, **kwargs):
    instance._audit_antes = None
    if raw or instance.pk is None:
        return
    instance._audit_antes = sender._default_manager.filter(pk=instance.pk).first()


def _despues(sender, instance, created, raw=False, update_fields=None, **kwargs):
    if raw:
        return
    entidad = sender.__name__
    if created:
        registrar("crear", entidad, instance.pk, {"repr": str(instance)[:200]})
        return
    antes = getattr(instance, "_audit_antes", None)
    if antes is None:
        return

    cambios, password_cambio = [], False
    for campo in sender._meta.concrete_fields:
        nombre = campo.attname
        if update_fields is not None and campo.name not in update_fields and nombre not in update_fields:
            continue
        viejo, nuevo = getattr(antes, nombre), getattr(instance, nombre)
        if viejo == nuevo:
            continue
        if campo.name == "password":
            password_cambio = True  # nunca se guarda el valor
        elif campo.name not in EXCLUIDOS:
            cambios.append((nombre, viejo, nuevo))

    if password_cambio:
        registrar("cambiar_password", entidad, instance.pk)
    if not cambios:
        return
    usuario = context.usuario_actual()
    HistorialCambios.objects.bulk_create(
        [
            HistorialCambios(
                entidad=entidad,
                entidad_id=str(instance.pk),
                campo=nombre,
                valor_anterior=_texto(viejo),
                valor_nuevo=_texto(nuevo),
                usuario=usuario,
            )
            for nombre, viejo, nuevo in cambios
        ]
    )
    registrar("editar", entidad, instance.pk, {"campos": [c[0] for c in cambios]})


def _eliminado(sender, instance, **kwargs):
    registrar("eliminar", sender.__name__, instance.pk, {"repr": str(instance)[:200]})


def _permisos_rol(sender, instance, action, pk_set, **kwargs):
    if action in ("post_add", "post_remove", "post_clear"):
        registrar(
            "editar_permisos", "Rol", instance.pk,
            {"operacion": action, "permisos": sorted(pk_set or [])},
        )


def conectar():
    for etiqueta in MODELOS:
        modelo = apps.get_model(etiqueta)
        pre_save.connect(_antes, sender=modelo, dispatch_uid=f"audit_pre_{etiqueta}")
        post_save.connect(_despues, sender=modelo, dispatch_uid=f"audit_post_{etiqueta}")
        post_delete.connect(_eliminado, sender=modelo, dispatch_uid=f"audit_del_{etiqueta}")
    Rol = apps.get_model("authentication.Rol")
    m2m_changed.connect(_permisos_rol, sender=Rol.permisos.through, dispatch_uid="audit_rol_permisos")