from pathlib import Path

from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

from .models import Permiso, Rol, Usuario


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)
    # Solo hace falta si la cuenta tiene varios roles (nombre del rol elegido).
    rol = serializers.CharField(required=False, allow_blank=True)


class RefreshSerializer(serializers.Serializer):
    refresh = serializers.CharField()


class TokensSerializer(serializers.Serializer):
    access = serializers.CharField()
    refresh = serializers.CharField()


def _version_foto(usuario):
    """Identificador de la foto actual (cambia en cada subida) o None si no tiene."""
    return Path(usuario.foto.name).stem if usuario.foto else None


class FotoSerializer(serializers.Serializer):
    foto = serializers.FileField()


class UsuarioSerializer(serializers.ModelSerializer):
    rol = serializers.CharField(source="rol.nombre")  # rol de esta sesión
    roles = serializers.SerializerMethodField()  # todos los roles de la cuenta
    permisos = serializers.SerializerMethodField()
    foto_version = serializers.SerializerMethodField()

    class Meta:
        model = Usuario
        fields = [
            "id", "nombre", "email", "rol", "roles", "permisos", "activo",
            "fecha_creacion", "foto_version",
        ]

    def get_roles(self, obj) -> list[str]:
        return [r.nombre for r in obj.roles_disponibles()]

    def get_foto_version(self, obj) -> str | None:
        return _version_foto(obj)

    def get_permisos(self, obj) -> list[str]:
        return list(obj.rol.permisos.values_list("nombre", flat=True))


class UsuarioListSerializer(serializers.ModelSerializer):
    rol_nombre = serializers.CharField(source="rol.nombre", read_only=True)
    roles = serializers.SerializerMethodField()
    roles_nombres = serializers.SerializerMethodField()
    foto_version = serializers.SerializerMethodField()

    class Meta:
        model = Usuario
        fields = [
            "id", "nombre", "email", "rol", "rol_nombre", "roles",
            "roles_nombres", "activo", "fecha_creacion", "foto_version",
        ]

    def get_roles(self, obj) -> list[int]:
        return [r.id for r in obj.roles_disponibles()]

    def get_roles_nombres(self, obj) -> list[str]:
        return [r.nombre for r in obj.roles_disponibles()]

    def get_foto_version(self, obj) -> str | None:
        return _version_foto(obj)


class UsuarioWriteSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True, required=False, validators=[validate_password]
    )

    # Todos los roles con los que puede entrar (el principal siempre se incluye).
    roles = serializers.PrimaryKeyRelatedField(
        many=True, queryset=Rol.objects.all(), required=False
    )

    class Meta:
        model = Usuario
        fields = ["id", "nombre", "email", "password", "rol", "roles", "activo"]

    def validate_roles(self, value):
        request = self.context.get("request")
        if self.instance and request and self.instance.pk == request.user.pk:
            actuales = {r.id for r in self.instance.roles_disponibles()}
            if not actuales <= {r.id for r in value}:
                raise serializers.ValidationError(
                    "No puedes quitarte roles a ti mismo."
                )
        return value

    def validate_rol(self, value):
        request = self.context.get("request")
        if (
            self.instance
            and request
            and self.instance.pk == request.user.pk
            and value != self.instance.rol
        ):
            raise serializers.ValidationError("No puedes cambiar tu propio rol.")
        return value

    def validate_activo(self, value):
        request = self.context.get("request")
        if (
            not value
            and self.instance
            and request
            and self.instance.pk == request.user.pk
        ):
            raise serializers.ValidationError("No puedes desactivar tu propia cuenta.")
        return value

    def validate(self, attrs):
        if self.instance is None and not attrs.get("password"):
            raise serializers.ValidationError(
                {"password": "La contraseña es obligatoria."}
            )
        return attrs

    def create(self, validated_data):
        password = validated_data.pop("password")
        roles = validated_data.pop("roles", [])
        usuario = Usuario.objects.create_user(password=password, **validated_data)
        usuario.roles.add(*roles)
        return usuario

    def update(self, instance, validated_data):
        password = validated_data.pop("password", None)
        usuario = super().update(instance, validated_data)
        usuario.roles.add(usuario.rol)  # el rol principal siempre está disponible
        if password:
            usuario.set_password(password)
            usuario.save(update_fields=["password"])
            usuario.refresh_tokens.update(revocado=True)  # cierra las sesiones abiertas
        if not usuario.activo:
            usuario.refresh_tokens.update(revocado=True)
        return usuario


class PermisoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Permiso
        fields = ["id", "nombre", "descripcion"]


class RolSerializer(serializers.ModelSerializer):
    permisos = serializers.PrimaryKeyRelatedField(
        many=True, queryset=Permiso.objects.all(), required=False
    )

    class Meta:
        model = Rol
        fields = ["id", "nombre", "descripcion", "permisos"]
        read_only_fields = ["nombre"]

    def validate(self, attrs):
        if (
            self.instance
            and self.instance.nombre == Rol.ADMINISTRADOR
            and "permisos" in attrs
        ):
            codigos = {p.nombre for p in attrs["permisos"]}
            if not {"usuarios.gestionar", "roles.gestionar"} <= codigos:
                raise serializers.ValidationError(
                    {
                        "permisos": "El rol Administrador debe conservar "
                        "'usuarios.gestionar' y 'roles.gestionar'."
                    }
                )
        return attrs