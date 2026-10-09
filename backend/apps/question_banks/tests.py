"""Pruebas del módulo question_banks: borrado real o desactivación de bancos y preguntas.

Ubicación: backend/apps/question_banks/tests.py
Ejecutar:  python -m pytest apps/question_banks/tests.py
"""
from datetime import timedelta

from django.core.management import call_command
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from apps.audit.models import Auditoria
from apps.authentication.models import Usuario
from apps.exams.models import Examen, ExamenPregunta
from apps.question_banks.models import BancoPreguntas, Materia, Pregunta


class BorradoBancosYPreguntasTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command("seed", verbosity=0)
        cls.docente = Usuario.objects.get(email="docente@demo.com")
        cls.estudiante = Usuario.objects.get(email="estudiante@demo.com")
        cls.otro_docente = Usuario.objects.create_user(
            "otro.doc@demo.com", "Otro Docente", "Demo12345*", rol=cls.docente.rol
        )
        cls.materia = Materia.objects.create(nombre="Redes")

    def setUp(self):
        self.client = APIClient()
        self.client.force_authenticate(self.docente)

    # ------------------------------ helpers ------------------------------
    def banco(self, docente=None, titulo="Banco"):
        return BancoPreguntas.objects.create(
            materia=self.materia, docente=docente or self.docente, titulo=titulo
        )

    def pregunta(self, banco):
        return Pregunta.objects.create(
            banco=banco, enunciado="¿Pregunta?", tipo=Pregunta.Tipo.ABIERTA, puntaje=1
        )

    def poner_en_examen(self, pregunta):
        ahora = timezone.now()
        examen = Examen.objects.create(
            docente=self.docente, materia=self.materia, titulo="Parcial",
            fecha_inicio=ahora + timedelta(hours=1), fecha_fin=ahora + timedelta(hours=3),
            duracion_minutos=30,
        )
        ExamenPregunta.objects.create(examen=examen, pregunta=pregunta, orden=1, puntaje=1)

    # ------------------------------ bancos ------------------------------
    def test_banco_sin_preguntas_se_elimina(self):
        banco = self.banco()
        r = self.client.delete(f"/api/bancos/{banco.pk}/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data["accion"], "eliminado")
        self.assertFalse(BancoPreguntas.objects.filter(pk=banco.pk).exists())
        self.assertTrue(
            Auditoria.objects.filter(
                accion="eliminar", entidad="BancoPreguntas", entidad_id=str(banco.pk)
            ).exists()
        )

    def test_banco_con_preguntas_se_desactiva(self):
        banco = self.banco()
        self.pregunta(banco)
        r = self.client.delete(f"/api/bancos/{banco.pk}/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data["accion"], "desactivado")
        banco.refresh_from_db()
        self.assertFalse(banco.activo)
        self.assertEqual(banco.preguntas.count(), 1)

    def test_docente_no_elimina_banco_ajeno(self):
        banco = self.banco(docente=self.otro_docente)
        r = self.client.delete(f"/api/bancos/{banco.pk}/")
        self.assertEqual(r.status_code, 404)
        self.assertTrue(BancoPreguntas.objects.filter(pk=banco.pk).exists())

    def test_estudiante_no_puede_eliminar_bancos(self):
        banco = self.banco()
        c = APIClient()
        c.force_authenticate(self.estudiante)
        r = c.delete(f"/api/bancos/{banco.pk}/")
        self.assertEqual(r.status_code, 403)
        self.assertTrue(BancoPreguntas.objects.filter(pk=banco.pk).exists())

    # ------------------------------ preguntas ------------------------------
    def test_pregunta_sin_uso_se_elimina(self):
        pregunta = self.pregunta(self.banco())
        r = self.client.delete(f"/api/preguntas/{pregunta.pk}/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data["accion"], "eliminado")
        self.assertFalse(Pregunta.objects.filter(pk=pregunta.pk).exists())

    def test_pregunta_usada_en_examen_se_desactiva(self):
        pregunta = self.pregunta(self.banco())
        self.poner_en_examen(pregunta)
        r = self.client.delete(f"/api/preguntas/{pregunta.pk}/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data["accion"], "desactivado")
        pregunta.refresh_from_db()
        self.assertFalse(pregunta.activo)
        self.assertEqual(pregunta.en_examenes.count(), 1)

    def test_docente_no_elimina_pregunta_ajena(self):
        pregunta = self.pregunta(self.banco(docente=self.otro_docente))
        r = self.client.delete(f"/api/preguntas/{pregunta.pk}/")
        self.assertEqual(r.status_code, 404)
        self.assertTrue(Pregunta.objects.filter(pk=pregunta.pk).exists())