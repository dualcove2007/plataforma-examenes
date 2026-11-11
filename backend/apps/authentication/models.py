import uuid
from pathlib import Path

from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.db import models


def ruta_foto(instancia, nombre_original):
    """Nombre generado (uuid): nunca se confía en el nombre del cliente."""
    extension = Path(nombre_original).suffix.lower()
    return f"usuarios/{instancia.pk}/{uuid.uuid4().hex}{extension}"


class Permiso(models.Model):
    nombre = models.CharField(max_length=100, unique=True)
    descripcion = models.CharField(max_length=255, blank=True)

    class Meta:
        db_table = "permisos"

    def __str__(self):
        return self.nombre


class Rol(models.Model):
    ADMINISTRADOR = "Administrador"
    DOCENTE = "Docente"
    ESTUDIANTE = "Estudiante"

    nombre = models.CharField(max_length=50, unique=True)
    descripcion = models.CharField(max_length=255, blank=True)
    permisos = models.ManyToManyField(
        Permiso, through="RolPermiso", related_name="roles"
    )

    class Meta:
        db_table = "roles"

    def __str__(self):
        return self.nombre


class RolPermiso(models.Model):
    rol = models.ForeignKey(Rol, on_delete=models.CASCADE)
    permiso = models.ForeignKey(Permiso, on_delete=models.CASCADE)

    class Meta:
        db_table = "rol_permisos"
        constraints = [
            models.UniqueConstraint(
                fields=["rol", "permiso"], name="uq_rol_permiso"
            )
        ]


class UsuarioManager(BaseUserManager):
    def create_user(self, email, nombre, password=None, rol=None, **extra):
        if not email:
            raise ValueError("El email es obligatorio")
        user = self.model(
            email=self.normalize_email(email), nombre=nombre, rol=rol, **extra
        )
        user.set_password(password)
        user.save(using=self._db)
        user.roles.add(rol)  # el rol principal también es un rol disponible
        return user

    def create_superuser(self, email, nombre, password=None, **extra):
        rol, _ = Rol.objects.get_or_create(
            nombre=Rol.ADMINISTRADOR, defaults={"descripcion": "Acceso total"}
        )
        return self.create_user(email, nombre, password, rol=rol, **extra)


class Usuario(AbstractBaseUser):
    nombre = models.CharField(max_length=150)
    email = models.EmailField(unique=True)
    password = models.CharField(max_length=128, db_column="password_hash")
    # Rol principal (el de la cuenta). Durante una sesión, `rol` refleja el rol
    # elegido al iniciar sesión (ver `activar_rol`); lo guardado en la BDD no cambia.
    rol = models.ForeignKey(Rol, on_delete=models.PROTECT, related_name="usuarios")
    # Todos los roles con los que la persona puede entrar con este mismo correo.
    roles = models.ManyToManyField(Rol, related_name="usuarios_roles", blank=True)
    activo = models.BooleanField(default=True)
    foto = models.FileField(upload_to=ruta_foto, max_length=255, null=True, blank=True)
    fecha_creacion = models.DateTimeField(auto_now_add=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["nombre"]
    objects = UsuarioManager()

    class Meta:
        db_table = "usuarios"

    def __str__(self):
        return self.email

    # ── Roles múltiples ──

    def roles_disponibles(self):
        """Roles con los que puede iniciar sesión (siempre incluye el principal)."""
        principal_id = getattr(self, "_rol_principal_id", self.rol_id)
        roles = {r.id: r for r in self.roles.all()}
        if principal_id not in roles:
            roles[principal_id] = Rol.objects.get(pk=principal_id)
        return sorted(roles.values(), key=lambda r: r.id)

    def activar_rol(self, rol):
        """Usa `rol` como rol de esta sesión, solo en memoria (no se guarda)."""
        if not hasattr(self, "_rol_principal_id"):
            self._rol_principal_id = self.rol_id
        self.rol = rol

    def save(self, *args, **kwargs):
        # Si hay un rol de sesión activo, nunca se persiste en lugar del principal.
        principal_id = getattr(self, "_rol_principal_id", None)
        if principal_id is not None and self.rol_id != principal_id:
            activo = self.rol
            self.rol_id = principal_id
            try:
                super().save(*args, **kwargs)
            finally:
                self.rol = activo
        else:
            super().save(*args, **kwargs)

    # Compatibilidad con Django (login y admin)
    @property
    def is_active(self):
        return self.activo

    @property
    def is_staff(self):
        return self.rol.nombre == Rol.ADMINISTRADOR

    @property
    def is_superuser(self):
        return self.is_staff

    def has_perm(self, perm, obj=None):
        return self.is_superuser

    def has_module_perms(self, app_label):
        return self.is_superuser

    # Permisos del sistema (los usará DRF)
    def tiene_permiso(self, codigo):
        return self.activo and self.rol.permisos.filter(nombre=codigo).exists()


class RefreshToken(models.Model):
    usuario = models.ForeignKey(
        Usuario, on_delete=models.CASCADE, related_name="refresh_tokens"
    )
    token_hash = models.CharField(max_length=64, unique=True)
    fecha_creacion = models.DateTimeField(auto_now_add=True)
    fecha_expiracion = models.DateTimeField()
    revocado = models.BooleanField(default=False)

    class Meta:
        db_table = "refresh_tokens"