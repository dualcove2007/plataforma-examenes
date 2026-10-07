from contextvars import ContextVar

_ctx = ContextVar("audit_ctx", default=None)


def iniciar(ip):
    return _ctx.set({"usuario": None, "ip": ip})


def terminar(token):
    _ctx.reset(token)


def asignar_usuario(usuario):
    datos = _ctx.get()
    if datos is not None:
        datos["usuario"] = usuario


def usuario_actual():
    datos = _ctx.get()
    usuario = datos["usuario"] if datos else None
    return usuario if usuario is not None and usuario.is_authenticated else None


def ip_actual():
    datos = _ctx.get()
    return datos["ip"] if datos else None