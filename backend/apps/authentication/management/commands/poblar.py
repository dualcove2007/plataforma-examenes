from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.audit import context
from apps.authentication.models import Rol, Usuario
from apps.question_banks.models import (
    BancoPreguntas,
    Materia,
    OpcionRespuesta,
    Pregunta,
)

T = Pregunta.Tipo
D = Pregunta.Dificultad

DOCENTES = [
    ("Carlos Mendoza", "carlos.mendoza@demo.com"),
    ("Natalia Ortiz", "natalia.ortiz@demo.com"),
]

ESTUDIANTES = [
    ("Laura Martínez", "laura.martinez@demo.com"),
    ("Andrés Gómez", "andres.gomez@demo.com"),
    ("Camila Rojas", "camila.rojas@demo.com"),
    ("Santiago Pérez", "santiago.perez@demo.com"),
    ("Valentina Torres", "valentina.torres@demo.com"),
    ("Daniel Ramírez", "daniel.ramirez@demo.com"),
    ("Sofía Herrera", "sofia.herrera@demo.com"),
    ("Juan Pablo Castro", "juan.castro@demo.com"),
    ("María Fernanda Díaz", "maria.diaz@demo.com"),
    ("Sebastián Vargas", "sebastian.vargas@demo.com"),
    ("Isabella Moreno", "isabella.moreno@demo.com"),
]

# Cada pregunta: (enunciado, tipo, dificultad, puntaje, detalle)
#   detalle en preguntas cerradas: [(texto, es_correcta), ...]
#   detalle en preguntas abiertas: [respuestas de ejemplo de estudiantes]
CATALOGO = [
    {
        "docente": "docente@demo.com",
        "materia": ("Bases de Datos", "Modelado relacional y lenguaje SQL"),
        "banco": "Banco general de Bases de Datos",
        "preguntas": [
            (
                "¿Qué sentencia SQL se usa para consultar datos de una tabla?",
                T.OPCION_UNICA, D.FACIL, 1.0,
                [("SELECT", True), ("INSERT", False), ("UPDATE", False), ("DROP", False)],
            ),
            (
                "¿Cuáles de las siguientes son propiedades ACID de una transacción?",
                T.OPCION_MULTIPLE, D.MEDIA, 1.5,
                [("Atomicidad", True), ("Aislamiento", True), ("Durabilidad", True),
                 ("Replicación", False)],
            ),
            (
                "Una llave primaria puede contener valores nulos.",
                T.VERDADERO_FALSO, D.FACIL, 0.5,
                [("Verdadero", False), ("Falso", True)],
            ),
            (
                "¿Qué forma normal elimina las dependencias parciales de la llave primaria?",
                T.OPCION_UNICA, D.MEDIA, 1.0,
                [("Segunda forma normal (2FN)", True), ("Primera forma normal (1FN)", False),
                 ("Tercera forma normal (3FN)", False), ("Forma normal de Boyce-Codd", False)],
            ),
            (
                "¿Qué tipo de JOIN devuelve solo las filas que coinciden en ambas tablas?",
                T.OPCION_UNICA, D.FACIL, 1.0,
                [("INNER JOIN", True), ("LEFT JOIN", False), ("RIGHT JOIN", False),
                 ("CROSS JOIN", False)],
            ),
            (
                "Explica con tus palabras para qué sirve un índice en una base de datos.",
                T.ABIERTA, D.DIFICIL, 2.0,
                [],
            ),
        ],
    },
    {
        "docente": "carlos.mendoza@demo.com",
        "materia": ("Programación Web", "Desarrollo de aplicaciones web y APIs REST"),
        "banco": "Banco general de Programación Web",
        "preguntas": [
            (
                "¿Qué método HTTP se usa normalmente para crear un recurso en una API REST?",
                T.OPCION_UNICA, D.FACIL, 1.0,
                [("POST", True), ("GET", False), ("PUT", False), ("DELETE", False)],
            ),
            (
                "¿Cuáles de los siguientes son frameworks o librerías de frontend?",
                T.OPCION_MULTIPLE, D.MEDIA, 1.5,
                [("Angular", True), ("React", True), ("Vue", True), ("Django", False)],
            ),
            (
                "El código de estado HTTP 404 indica que no se encontró el recurso solicitado.",
                T.VERDADERO_FALSO, D.FACIL, 0.5,
                [("Verdadero", True), ("Falso", False)],
            ),
            (
                "¿Qué significa la sigla CORS?",
                T.OPCION_UNICA, D.MEDIA, 1.0,
                [("Intercambio de recursos de origen cruzado", True),
                 ("Control de operaciones en red segura", False),
                 ("Compresión de objetos y recursos del servidor", False),
                 ("Cola ordenada de respuestas síncronas", False)],
            ),
            (
                "¿Qué mecanismo permite autenticar peticiones a una API sin guardar sesión "
                "en el servidor?",
                T.OPCION_UNICA, D.MEDIA, 1.0,
                [("JWT (JSON Web Token)", True), ("Un archivo .env", False),
                 ("Una hoja de estilos", False), ("Un favicon", False)],
            ),
            (
                "Describe la diferencia entre autenticación y autorización.",
                T.ABIERTA, D.DIFICIL, 2.0,
                [],
            ),
        ],
    },
    {
        "docente": "natalia.ortiz@demo.com",
        "materia": ("Ingeniería de Software", "Procesos, metodologías y calidad del software"),
        "banco": "Banco general de Ingeniería de Software",
        "preguntas": [
            (
                "¿Cuál de los siguientes es un sistema de control de versiones distribuido?",
                T.OPCION_UNICA, D.FACIL, 1.0,
                [("Git", True), ("FTP", False), ("DNS", False), ("SMTP", False)],
            ),
            (
                "¿Cuáles son valores del Manifiesto Ágil?",
                T.OPCION_MULTIPLE, D.MEDIA, 1.5,
                [("Individuos e interacciones", True), ("Software funcionando", True),
                 ("Colaboración con el cliente", True),
                 ("Documentación exhaustiva por encima de todo", False)],
            ),
            (
                "Las pruebas unitarias verifican el funcionamiento de módulos individuales.",
                T.VERDADERO_FALSO, D.FACIL, 0.5,
                [("Verdadero", True), ("Falso", False)],
            ),
            (
                "¿Qué metodología organiza el trabajo en sprints?",
                T.OPCION_UNICA, D.MEDIA, 1.0,
                [("Scrum", True), ("Cascada", False), ("Espiral", False), ("Modelo en V", False)],
            ),
            (
                "¿Qué diagrama UML muestra cómo interactúa un usuario con el sistema?",
                T.OPCION_UNICA, D.MEDIA, 1.0,
                [("Diagrama de casos de uso", True), ("Diagrama de clases", False),
                 ("Diagrama de despliegue", False), ("Diagrama de componentes", False)],
            ),
            (
                "Explica qué es la integración continua y qué ventaja aporta a un equipo.",
                T.ABIERTA, D.DIFICIL, 2.0,
                [],
            ),
        ],
    },
]

class Command(BaseCommand):
    help = (
        "Crea datos base para trabajar: docentes, estudiantes, materias, bancos y "
        "preguntas. No crea exámenes ni resultados. Requiere haber corrido seed."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--password",
            default="Demo12345*",
            help="Contraseña de los docentes y estudiantes nuevos.",
        )

    @transaction.atomic
    def handle(self, *args, **options):
        admin = Usuario.objects.filter(email="admin@demo.com").first()
        if admin is None:
            raise CommandError("Faltan los usuarios de prueba. Corre primero: manage.py seed")
        if Materia.objects.filter(nombre__in=[c["materia"][0] for c in CATALOGO]).exists():
            raise CommandError("Ya existen materias de ejemplo. Vacía la base antes de poblar.")

        token = context.iniciar("127.0.0.1")
        try:
            context.asignar_usuario(admin)
            docentes = self._crear_usuarios(Rol.DOCENTE, DOCENTES, options["password"])
            estudiantes = self._crear_usuarios(Rol.ESTUDIANTE, ESTUDIANTES, options["password"])

            total_preguntas = 0
            for bloque in CATALOGO:
                nombre, descripcion = bloque["materia"]
                context.asignar_usuario(admin)
                materia = Materia.objects.create(nombre=nombre, descripcion=descripcion)

                docente = Usuario.objects.get(email=bloque["docente"])
                context.asignar_usuario(docente)
                banco = BancoPreguntas.objects.create(
                    materia=materia, docente=docente, titulo=bloque["banco"],
                    descripcion=f"Preguntas de {nombre} para parciales y quices",
                )
                total_preguntas += self._crear_preguntas(banco, bloque["preguntas"])
        finally:
            context.terminar(token)

        self.stdout.write(
            self.style.SUCCESS(
                f"Listo: {len(docentes)} docentes y {len(estudiantes)} estudiantes nuevos, "
                f"{len(CATALOGO)} materias, {len(CATALOGO)} bancos y "
                f"{total_preguntas} preguntas."
            )
        )

    def _crear_usuarios(self, nombre_rol, datos, password):
        rol = Rol.objects.get(nombre=nombre_rol)
        creados = []
        for nombre, email in datos:
            if not Usuario.objects.filter(email=email).exists():
                creados.append(Usuario.objects.create_user(email, nombre, password, rol=rol))
        return creados

    def _crear_preguntas(self, banco, definiciones):
        for enunciado, tipo, dificultad, puntaje, detalle in definiciones:
            p = Pregunta.objects.create(
                banco=banco, enunciado=enunciado, tipo=tipo,
                dificultad=dificultad, puntaje=puntaje,
            )
            OpcionRespuesta.objects.bulk_create(
                [OpcionRespuesta(pregunta=p, texto=t, es_correcta=c) for t, c in detalle]
            )
        return len(definiciones)
