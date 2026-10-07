from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

from .models import Permiso, Rol, Usuario


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


class UsuarioListSerializer(serializers.ModelSerializer):
    rol_nombre = serializers.CharField(source="rol.nombre", read_only=True)

    class Meta:
        model = Usuario
        fields = ["id", "nombre", "email", "rol", "rol_nombre", "activo", "fecha_creacion"]


class UsuarioWriteSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True, required=False, validators=[validate_password]
    )

    class Meta:
        model = Usuario
        fields = ["id", "nombre", "email", "password", "rol", "activo"]

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
        return Usuario.objects.create_user(password=password, **validated_data)

    def update(self, instance, validated_data):
        password = validated_data.pop("password", None)
        usuario = super().update(instance, validated_data)
        if password:
            usuario.set_password(password)
            usuario.save(update_fields=["password"])
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