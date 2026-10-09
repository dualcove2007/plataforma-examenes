from datetime import timedelta

from django.core.management import call_command
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from apps.attempts.models import Intento, ResultadoExamen
from apps.audit.models import Auditoria
from apps.authentication.models import Usuario
from apps.exams.models import AsignacionExamen, Examen
from apps.question_banks.models import Materia


class ConstanciaTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command("seed", verbosity=0)
        cls.docente = Usuario.objects.get(email="docente@demo.com")
        cls.estudiante = Usuario.objects.get(email="estudiante@demo.com")
        cls.otro_estudiante = Usuario.objects.create_user(
            "otro.est@demo.com", "Otro Estudiante", "Demo12345*", rol=cls.estudiante.rol
        )
        materia = Materia.objects.create(nombre="Redes")
        ahora = timezone.now()
        examen = Examen.objects.create(
            docente=cls.docente, materia=materia, titulo="Parcial 1",
            fecha_inicio=ahora - timedelta(days=2), fecha_fin=ahora - timedelta(days=1),
            duracion_minutos=30, estado=Examen.Estado.CERRADO,
        )
        asignacion = AsignacionExamen.objects.create(examen=examen, estudiante=cls.estudiante)

        def resultado(numero, revision):
            intento = Intento.objects.create(
                asignacion=asignacion, numero_intento=numero,
                fecha_limite=ahora - timedelta(days=1), fecha_fin=ahora - timedelta(days=1),
                estado=Intento.Estado.FINALIZADO,
            )
            return ResultadoExamen.objects.create(
                intento=intento, puntaje_total=4, puntaje_maximo=5, nota_final=4.0,
                estado_revision=revision,
            )

        cls.revisado = resultado(1, ResultadoExamen.Revision.REVISADO)
        cls.pendiente = resultado(2, ResultadoExamen.Revision.PENDIENTE)

    def get(self, usuario, resultado):
        cliente = APIClient()
        if usuario:
            cliente.force_authenticate(usuario)
        return cliente.get(f"/api/reportes/constancia/{resultado.pk}/")

    def test_estudiante_descarga_su_constancia(self):
        r = self.get(self.estudiante, self.revisado)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r["Content-Type"], "application/pdf")
        self.assertTrue(r.content.startswith(b"%PDF"))
        self.assertIn(f"constancia_resultado_{self.revisado.pk}.pdf", r["Content-Disposition"])

    def test_no_se_entrega_si_no_esta_revisado(self):
        self.assertEqual(self.get(self.estudiante, self.pendiente).status_code, 400)

    def test_otro_estudiante_no_la_ve(self):
        self.assertEqual(self.get(self.otro_estudiante, self.revisado).status_code, 404)

    def test_docente_no_tiene_permiso(self):
        self.assertEqual(self.get(self.docente, self.revisado).status_code, 403)

    def test_sin_autenticar(self):
        self.assertIn(self.get(None, self.revisado).status_code, (401, 403))

    def test_queda_registrado_en_auditoria(self):
        self.get(self.estudiante, self.revisado)
        self.assertTrue(
            Auditoria.objects.filter(
                accion="exportar", entidad="Resultado", entidad_id=str(self.revisado.pk)
            ).exists()
        )