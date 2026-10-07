from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.db import models


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
    rol = models.ForeignKey(Rol, on_delete=models.PROTECT, related_name="usuarios")
    activo = models.BooleanField(default=True)
    fecha_creacion = models.DateTimeField(auto_now_add=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["nombre"]
    objects = UsuarioManager()

    class Meta:
        db_table = "usuarios"

    def __str__(self):
        return self.email

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