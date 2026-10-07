from . import context
from .models import Auditoria, HistorialEstado


def registrar(accion, entidad, entidad_id="", detalle=None, usuario=None):
    """Escribe una fila en auditoria. Si no se pasa usuario, usa el de la petición."""
    return Auditoria.objects.create(
        usuario=usuario or context.usuario_actual(),
        accion=accion,
        entidad=entidad,
        entidad_id=str(entidad_id),
        ip_address=context.ip_actual(),
        detalle=detalle or {},
    )


def registrar_transicion(entidad, entidad_id, anterior, nuevo, usuario=None):
    """Historial de estado + una entrada de auditoría."""
    usuario = usuario or context.usuario_actual()
    anterior, nuevo = str(anterior or ""), str(nuevo)
    HistorialEstado.objects.create(
        entidad=entidad,
        entidad_id=str(entidad_id),
        estado_anterior=anterior,
        estado_nuevo=nuevo,
        usuario=usuario,
    )
    registrar("cambiar_estado", entidad, entidad_id, {"de": anterior, "a": nuevo}, usuario)