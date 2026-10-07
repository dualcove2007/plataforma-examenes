from rest_framework import serializers

from .models import Auditoria, HistorialCambios, HistorialEstado


class _ConUsuario(serializers.ModelSerializer):
    usuario_nombre = serializers.CharField(
        source="usuario.nombre", read_only=True, default=None
    )


class AuditoriaSerializer(_ConUsuario):
    class Meta:
        model = Auditoria
        fields = [
            "id", "usuario", "usuario_nombre", "accion", "entidad",
            "entidad_id", "ip_address", "fecha", "detalle",
        ]


class HistorialCambiosSerializer(_ConUsuario):
    class Meta:
        model = HistorialCambios
        fields = [
            "id", "entidad", "entidad_id", "campo", "valor_anterior",
            "valor_nuevo", "usuario", "usuario_nombre", "fecha",
        ]


class HistorialEstadoSerializer(_ConUsuario):
    class Meta:
        model = HistorialEstado
        fields = [
            "id", "entidad", "entidad_id", "estado_anterior",
            "estado_nuevo", "usuario", "usuario_nombre", "fecha",
        ]