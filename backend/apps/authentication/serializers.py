from rest_framework import serializers

from .models import Usuario


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)


class RefreshSerializer(serializers.Serializer):
    refresh = serializers.CharField()


class TokensSerializer(serializers.Serializer):
    access = serializers.CharField()
    refresh = serializers.CharField()


class UsuarioSerializer(serializers.ModelSerializer):
    rol = serializers.CharField(source="rol.nombre")
    permisos = serializers.SerializerMethodField()

    class Meta:
        model = Usuario
        fields = ["id", "nombre", "email", "rol", "permisos", "activo", "fecha_creacion"]

    def get_permisos(self, obj) -> list[str]:
        return list(obj.rol.permisos.values_list("nombre", flat=True))