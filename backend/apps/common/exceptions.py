from django.db.models import ProtectedError
from rest_framework.response import Response
from rest_framework.views import exception_handler


def _error(codigo, mensaje, detalles=None):
    return {"error": {"codigo": codigo, "mensaje": mensaje, "detalles": detalles}}


def manejador_excepciones(exc, context):
    if isinstance(exc, ProtectedError):
        return Response(
            _error(409, "No se puede eliminar: tiene registros relacionados."),
            status=409,
        )

    response = exception_handler(exc, context)
    if response is None:
        return None  # errores 500: los maneja Django

    data = response.data
    if isinstance(data, dict) and "detail" in data:
        response.data = _error(response.status_code, str(data["detail"]))
    elif isinstance(data, list):
        response.data = _error(response.status_code, " ".join(str(m) for m in data))
    else:
        response.data = _error(response.status_code, "Datos inválidos.", data)
    return response