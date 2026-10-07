from django.core.management.base import BaseCommand
from django.db import transaction

from apps.authentication.models import Permiso, Rol, RolPermiso, Usuario

PERMISOS = {
    "usuarios.gestionar": "Crear, editar y desactivar usuarios",
    "roles.gestionar": "Administrar roles y permisos",
    "materias.gestionar": "Administrar materias",
    "bancos.gestionar": "Administrar bancos de preguntas",
    "preguntas.gestionar": "Administrar preguntas y opciones",
    "examenes.gestionar": "Crear y configurar exámenes",
    "examenes.asignar": "Asignar exámenes a estudiantes",
    "examenes.rendir": "Presentar exámenes asignados",
    "resultados.ver_propios": "Ver resultados propios",
    "resultados.ver_todos": "Ver resultados de todos los estudiantes",
    "resultados.calificar": "Revisar y calificar respuestas abiertas",
    "reportes.ver": "Generar reportes y exportaciones",
    "auditoria.ver": "Consultar auditoría e historial",
}

ROLES = {
    Rol.ADMINISTRADOR: (
        "Gestiona usuarios, roles y auditoría",
        [
            "usuarios.gestionar",
            "roles.gestionar",
            "materias.gestionar",
            "resultados.ver_todos",
            "reportes.ver",
            "auditoria.ver",
        ],
    ),
    Rol.DOCENTE: (
        "Crea bancos, preguntas y exámenes",
        [
            "bancos.gestionar",
            "preguntas.gestionar",
            "examenes.gestionar",
            "examenes.asignar",
            "resultados.ver_todos",
            "resultados.calificar",
            "reportes.ver",
        ],
    ),
    Rol.ESTUDIANTE: (
        "Presenta exámenes y consulta sus resultados",
        ["examenes.rendir", "resultados.ver_propios"],
    ),
}

USUARIOS = [
    ("Admin Demo", "admin@demo.com", Rol.ADMINISTRADOR),
    ("Docente Demo", "docente@demo.com", Rol.DOCENTE),
    ("Estudiante Demo", "estudiante@demo.com", Rol.ESTUDIANTE),
]


class Command(BaseCommand):
    help = "Crea roles, permisos y usuarios de prueba (se puede repetir sin duplicar)."

    def add_arguments(self, parser):
        parser.add_argument("--password", default="Demo12345*")

    @transaction.atomic
    def handle(self, *args, **options):
        permisos = {}
        for nombre, descripcion in PERMISOS.items():
            permisos[nombre], _ = Permiso.objects.get_or_create(
                nombre=nombre, defaults={"descripcion": descripcion}
            )

        roles = {}
        for nombre, (descripcion, codigos) in ROLES.items():
            rol, _ = Rol.objects.get_or_create(
                nombre=nombre, defaults={"descripcion": descripcion}
            )
            roles[nombre] = rol
            for codigo in codigos:
                RolPermiso.objects.get_or_create(rol=rol, permiso=permisos[codigo])

        for nombre, email, rol_nombre in USUARIOS:
            if not Usuario.objects.filter(email=email).exists():
                Usuario.objects.create_user(
                    email, nombre, options["password"], rol=roles[rol_nombre]
                )
                self.stdout.write(f"Usuario creado: {email}")

        self.stdout.write(
            self.style.SUCCESS(
                f"Listo. Usuarios de prueba con contraseña: {options['password']}"
            )
        )