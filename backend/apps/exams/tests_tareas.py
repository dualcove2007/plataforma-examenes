from datetime import timedelta

from django.core.management import call_command
from django.test import TestCase
from django.utils import timezone

from apps.attempts.models import Intento, ResultadoExamen
from apps.attempts.services import expirar_intentos_vencidos
from apps.authentication.models import Usuario
from apps.question_banks.models import Materia

from .models import AsignacionExamen, Examen
from .services import cerrar_examenes_vencidos


class TareasProgramadasTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command("seed", verbosity=0)
        cls.docente = Usuario.objects.get(email="docente@demo.com")
        cls.estudiante = Usuario.objects.get(email="estudiante@demo.com")
        cls.materia = Materia.objects.create(nombre="Redes")

    def examen(self, estado, fin):
        return Examen.objects.create(
            docente=self.docente, materia=self.materia, titulo="Parcial",
            fecha_inicio=timezone.now() - timedelta(days=2), fecha_fin=fin,
            duracion_minutos=30, estado=estado,
        )

    def test_cierra_examenes_publicados_vencidos(self):
        ex = self.examen(Examen.Estado.PUBLICADO, timezone.now() - timedelta(minutes=10))
        self.assertEqual(cerrar_examenes_vencidos(), 1)
        ex.refresh_from_db()
        self.assertEqual(ex.estado, Examen.Estado.CERRADO)

    def test_no_toca_vigentes_ni_borradores(self):
        vigente = self.examen(Examen.Estado.PUBLICADO, timezone.now() + timedelta(hours=1))
        borrador = self.examen(Examen.Estado.BORRADOR, timezone.now() - timedelta(minutes=10))
        self.assertEqual(cerrar_examenes_vencidos(), 0)
        vigente.refresh_from_db()
        borrador.refresh_from_db()
        self.assertEqual(vigente.estado, Examen.Estado.PUBLICADO)
        self.assertEqual(borrador.estado, Examen.Estado.BORRADOR)

    def test_expira_solo_intentos_vencidos(self):
        ex = self.examen(Examen.Estado.PUBLICADO, timezone.now() + timedelta(hours=1))
        asig = AsignacionExamen.objects.create(examen=ex, estudiante=self.estudiante)
        vencido = Intento.objects.create(
            asignacion=asig, numero_intento=1,
            fecha_limite=timezone.now() - timedelta(minutes=1),
        )
        self.assertEqual(expirar_intentos_vencidos(), 1)
        vencido.refresh_from_db()
        self.assertEqual(vencido.estado, Intento.Estado.EXPIRADO)
        self.assertTrue(ResultadoExamen.objects.filter(intento=vencido).exists())

    def test_no_expira_intento_vigente(self):
        ex = self.examen(Examen.Estado.PUBLICADO, timezone.now() + timedelta(hours=1))
        asig = AsignacionExamen.objects.create(examen=ex, estudiante=self.estudiante)
        vigente = Intento.objects.create(
            asignacion=asig, numero_intento=1,
            fecha_limite=timezone.now() + timedelta(minutes=10),
        )
        self.assertEqual(expirar_intentos_vencidos(), 0)
        vigente.refresh_from_db()
        self.assertEqual(vigente.estado, Intento.Estado.EN_PROGRESO)