from rest_framework.permissions import BasePermission


def tiene_permiso(codigo):
    """Uso: permission_classes = [IsAuthenticated, tiene_permiso("usuarios.gestionar")]"""

    class _TienePermiso(BasePermission):
        message = "No tienes permiso para realizar esta acción."

        def has_permission(self, request, view):
            usuario = request.user
            return bool(
                usuario and usuario.is_authenticated and usuario.tiene_permiso(codigo)
            )

    _TienePermiso.__name__ = f"TienePermiso_{codigo}"
    return _TienePermiso