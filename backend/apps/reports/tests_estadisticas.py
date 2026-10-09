from datetime import timedelta

from django.core.management import call_command
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from apps.attempts.models import Intento, ResultadoExamen
from apps.authentication.models import Usuario
from apps.exams.models import AsignacionExamen, Examen
from apps.question_banks.models import Materia

URL = "/api/reportes/estadisticas/"
REV = ResultadoExamen.Revision


class EstadisticasTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command("seed", verbosity=0)
        cls.admin = Usuario.objects.get(email="admin@demo.com")
        cls.docente = Usuario.objects.get(email="docente@demo.com")
        cls.estudiante = Usuario.objects.get(email="estudiante@demo.com")
        rol_est = cls.estudiante.rol
        e2 = Usuario.objects.create_user("e2@demo.com", "Est Dos", "Demo12345*", rol=rol_est)
        e3 = Usuario.objects.create_user("e3@demo.com", "Est Tres", "Demo12345*", rol=rol_est)
        otro = Usuario.objects.create_user(
            "otro@demo.com", "Otro Docente", "Demo12345*", rol=cls.docente.rol
        )
        materia = Materia.objects.create(nombre="Redes")
        cls.ahora = timezone.now()

        def examen(docente, titulo):
            return Examen.objects.create(
                docente=docente, materia=materia, titulo=titulo,
                fecha_inicio=cls.ahora - timedelta(days=2),
                fecha_fin=cls.ahora - timedelta(days=1),
                duracion_minutos=30, estado=Examen.Estado.CERRADO,
            )

        def presentar(ex, estudiante, nota, revision):
            asig = AsignacionExamen.objects.create(examen=ex, estudiante=estudiante)
            intento = Intento.objects.create(
                asignacion=asig, numero_intento=1, fecha_limite=cls.ahora,
                fecha_fin=cls.ahora, estado=Intento.Estado.FINALIZADO,
            )
            ResultadoExamen.objects.create(
                intento=intento, puntaje_total=nota, puntaje_maximo=5,
                nota_final=nota, estado_revision=revision,
            )

        cls.examen_a = examen(cls.docente, "Parcial A")
        cls.examen_b = examen(otro, "Parcial B")
        presentar(cls.examen_a, cls.estudiante, 4.0, REV.REVISADO)
        presentar(cls.examen_a, e2, 2.0, REV.REVISADO)
        presentar(cls.examen_a, e3, 1.0, REV.PENDIENTE)
        presentar(cls.examen_b, cls.estudiante, 5.0, REV.REVISADO)

    def get(self, usuario, **params):
        cliente = APIClient()
        if usuario:
            cliente.force_authenticate(usuario)
        return cliente.get(URL, params)

    def test_docente_solo_ve_sus_examenes(self):
        r = self.get(self.docente)
        self.assertEqual(r.status_code, 200)
        d = r.data
        self.assertEqual(d["examenes"]["total"], 1)
        self.assertEqual(d["examenes"]["cerrado"], 1)
        self.assertEqual(d["examenes"]["borrador"], 0)
        self.assertEqual(d["asignaciones"], 3)
        self.assertEqual(d["intentos"]["total"], 3)
        self.assertEqual(d["intentos"]["finalizado"], 3)
        res = d["resultados"]
        self.assertEqual(res["total"], 3)
        self.assertEqual(res["revisados"], 2)
        self.assertEqual(res["pendientes_revision"], 1)
        self.assertEqual(res["promedio_nota"], 3.0)
        self.assertEqual(res["aprobados"], 1)
        self.assertEqual(res["reprobados"], 1)
        self.assertEqual(res["tasa_aprobacion"], 50.0)
        self.assertEqual(len(d["por_examen"]), 1)
        fila = d["por_examen"][0]
        self.assertEqual(fila["asignados"], 3)
        self.assertEqual(fila["presentaron"], 3)
        self.assertEqual(fila["promedio_nota"], 3.0)

    def test_admin_ve_todo(self):
        d = self.get(self.admin).data
        self.assertEqual(d["examenes"]["total"], 2)
        self.assertEqual(d["resultados"]["total"], 4)
        self.assertEqual(d["resultados"]["revisados"], 3)
        self.assertEqual(d["resultados"]["promedio_nota"], 3.7)
        self.assertEqual(d["resultados"]["aprobados"], 2)
        self.assertEqual(len(d["por_examen"]), 2)

    def test_filtrar_por_examen(self):
        d = self.get(self.admin, examen=self.examen_b.pk).data
        self.assertEqual(d["examenes"]["total"], 1)
        self.assertEqual(d["resultados"]["total"], 1)
        self.assertEqual(d["resultados"]["promedio_nota"], 5.0)

    def test_docente_no_filtra_por_examen_ajeno(self):
        self.assertEqual(self.get(self.docente, examen=self.examen_b.pk).status_code, 404)

    def test_examen_invalido(self):
        self.assertEqual(self.get(self.docente, examen="abc").status_code, 400)

    def test_estudiante_no_tiene_permiso(self):
        self.assertEqual(self.get(self.estudiante).status_code, 403)

    def test_sin_datos_no_rompe(self):
        Intento.objects.all().delete()
        d = self.get(self.docente).data
        self.assertEqual(d["resultados"]["total"], 0)
        self.assertIsNone(d["resultados"]["promedio_nota"])
        self.assertIsNone(d["resultados"]["tasa_aprobacion"])