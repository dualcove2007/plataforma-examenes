import shutil
import tempfile
from datetime import timedelta
from pathlib import Path

from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient

from apps.authentication.models import Usuario
from apps.exams.models import AsignacionExamen, Examen, ExamenPregunta
from apps.question_banks.models import BancoPreguntas, Materia, Pregunta

from .models import ArchivoAdjunto

MEDIA_TEMPORAL = tempfile.mkdtemp()
MB = 1024 * 1024
PDF = b"%PDF-1.4\n" + b"0" * 100
PNG = b"\x89PNG\r\n\x1a\n" + b"0" * 100


def pdf(nombre="doc.pdf", relleno=0):
    return SimpleUploadedFile(nombre, PDF + b"0" * relleno, content_type="application/pdf")


@override_settings(MEDIA_ROOT=MEDIA_TEMPORAL)
class AdjuntosTests(TestCase):
    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()
        shutil.rmtree(MEDIA_TEMPORAL, ignore_errors=True)

    @classmethod
    def setUpTestData(cls):
        call_command("seed", verbosity=0)
        cls.admin = Usuario.objects.get(email="admin@demo.com")
        cls.docente = Usuario.objects.get(email="docente@demo.com")
        cls.estudiante = Usuario.objects.get(email="estudiante@demo.com")
        cls.otro_docente = Usuario.objects.create_user(
            "otro@demo.com", "Otro Docente", "Demo12345*", rol=cls.docente.rol
        )
        materia = Materia.objects.create(nombre="Bases de datos")
        banco = BancoPreguntas.objects.create(
            materia=materia, docente=cls.docente, titulo="Banco"
        )
        cls.pregunta = Pregunta.objects.create(
            banco=banco, enunciado="¿Qué es SQL?", tipo="abierta"
        )
        ahora = timezone.now()
        cls.examen = Examen.objects.create(
            docente=cls.docente, materia=materia, titulo="Parcial",
            fecha_inicio=ahora, fecha_fin=ahora + timedelta(days=1),
            duracion_minutos=30,
        )

    def cliente(self, usuario):
        c = APIClient()
        c.force_authenticate(usuario)
        return c

    def subir(self, usuario, archivo, **datos):
        return self.cliente(usuario).post(
            "/api/adjuntos/", {"archivo": archivo, **datos}, format="multipart"
        )

    def publicar(self):
        ExamenPregunta.objects.create(
            examen=self.examen, pregunta=self.pregunta, orden=1, puntaje=1
        )
        Examen.objects.filter(pk=self.examen.pk).update(estado="publicado")

    # --- subida ---
    def test_docente_sube_pdf_a_su_pregunta(self):
        r = self.subir(self.docente, pdf(), pregunta=self.pregunta.pk)
        self.assertEqual(r.status_code, 201, r.data)
        adjunto = ArchivoAdjunto.objects.get()
        self.assertTrue(Path(adjunto.archivo.path).exists())
        self.assertEqual(adjunto.tipo_mime, "application/pdf")
        self.assertNotIn("doc", Path(adjunto.archivo.name).stem)  # nombre generado

    def test_docente_sube_png_a_su_examen(self):
        png = SimpleUploadedFile("img.PNG", PNG, content_type="image/png")
        r = self.subir(self.docente, png, examen=self.examen.pk)
        self.assertEqual(r.status_code, 201, r.data)

    def test_docente_ajeno_no_puede_subir(self):
        r = self.subir(self.otro_docente, pdf(), pregunta=self.pregunta.pk)
        self.assertEqual(r.status_code, 403)

    def test_estudiante_no_puede_subir(self):
        r = self.subir(self.estudiante, pdf(), examen=self.examen.pk)
        self.assertEqual(r.status_code, 403)

    def test_admin_puede_subir(self):
        r = self.subir(self.admin, pdf(), examen=self.examen.pk)
        self.assertEqual(r.status_code, 201, r.data)

    # --- validaciones ---
    def test_extension_no_permitida(self):
        exe = SimpleUploadedFile("virus.exe", b"MZ" + b"0" * 50)
        r = self.subir(self.docente, exe, pregunta=self.pregunta.pk)
        self.assertEqual(r.status_code, 400)

    def test_contenido_no_coincide_con_extension(self):
        falso = SimpleUploadedFile("falso.pdf", b"esto es solo texto")
        r = self.subir(self.docente, falso, pregunta=self.pregunta.pk)
        self.assertEqual(r.status_code, 400)
        self.assertEqual(ArchivoAdjunto.objects.count(), 0)

    def test_png_con_firma_de_pdf_se_rechaza(self):
        falso = SimpleUploadedFile("x.png", PDF)
        r = self.subir(self.docente, falso, pregunta=self.pregunta.pk)
        self.assertEqual(r.status_code, 400)

    def test_limites_de_tamano(self):
        grande_png = SimpleUploadedFile("g.png", PNG + b"0" * (5 * MB))
        self.assertEqual(
            self.subir(self.docente, grande_png, pregunta=self.pregunta.pk).status_code, 400
        )
        pdf_8mb = pdf(relleno=8 * MB)
        self.assertEqual(
            self.subir(self.docente, pdf_8mb, pregunta=self.pregunta.pk).status_code, 201
        )
        pdf_11mb = pdf("g.pdf", relleno=11 * MB)
        self.assertEqual(
            self.subir(self.docente, pdf_11mb, pregunta=self.pregunta.pk).status_code, 400
        )

    def test_archivo_vacio(self):
        vacio = SimpleUploadedFile("v.pdf", b"")
        r = self.subir(self.docente, vacio, pregunta=self.pregunta.pk)
        self.assertEqual(r.status_code, 400)

    def test_exige_exactamente_un_dueno(self):
        r = self.subir(self.docente, pdf())
        self.assertEqual(r.status_code, 400)
        r = self.subir(
            self.docente, pdf(), pregunta=self.pregunta.pk, examen=self.examen.pk
        )
        self.assertEqual(r.status_code, 400)

    def test_examen_publicado_no_admite_cambios(self):
        self.publicar()
        r = self.subir(self.docente, pdf(), examen=self.examen.pk)
        self.assertEqual(r.status_code, 400)
        r = self.subir(self.docente, pdf(), pregunta=self.pregunta.pk)
        self.assertEqual(r.status_code, 400)

    # --- descarga y visibilidad ---
    def test_descarga_segun_rol(self):
        self.subir(self.docente, pdf(), examen=self.examen.pk)
        adjunto = ArchivoAdjunto.objects.get()
        url = f"/api/adjuntos/{adjunto.pk}/descargar/"

        self.assertEqual(self.cliente(self.docente).get(url).status_code, 200)
        self.assertEqual(self.cliente(self.admin).get(url).status_code, 200)
        self.assertEqual(self.cliente(self.otro_docente).get(url).status_code, 404)
        # Estudiante sin asignación
        self.assertEqual(self.cliente(self.estudiante).get(url).status_code, 404)

        AsignacionExamen.objects.create(examen=self.examen, estudiante=self.estudiante)
        # Asignado pero el examen sigue en borrador
        self.assertEqual(self.cliente(self.estudiante).get(url).status_code, 404)

        ExamenPregunta.objects.create(
            examen=self.examen, pregunta=self.pregunta, orden=1, puntaje=1
        )
        Examen.objects.filter(pk=self.examen.pk).update(estado="publicado")
        r = self.cliente(self.estudiante).get(url)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r["Content-Type"], "application/pdf")
        self.assertEqual(r["X-Content-Type-Options"], "nosniff")
        b"".join(r.streaming_content)

    def test_estudiante_ve_adjuntos_de_preguntas_de_su_examen(self):
        self.subir(self.docente, pdf(), pregunta=self.pregunta.pk)
        ExamenPregunta.objects.create(
            examen=self.examen, pregunta=self.pregunta, orden=1, puntaje=1
        )
        AsignacionExamen.objects.create(examen=self.examen, estudiante=self.estudiante)
        r = self.cliente(self.estudiante).get("/api/adjuntos/")
        self.assertEqual(r.data["count"], 0)  # examen aún en borrador
        Examen.objects.filter(pk=self.examen.pk).update(estado="publicado")
        r = self.cliente(self.estudiante).get("/api/adjuntos/")
        self.assertEqual(r.data["count"], 1)

    def test_listado_filtra_por_dueno(self):
        self.subir(self.docente, pdf(), pregunta=self.pregunta.pk)
        self.subir(self.docente, pdf(), examen=self.examen.pk)
        r = self.cliente(self.docente).get(f"/api/adjuntos/?examen={self.examen.pk}")
        self.assertEqual(r.data["count"], 1)
        r = self.cliente(self.otro_docente).get("/api/adjuntos/")
        self.assertEqual(r.data["count"], 0)

    # --- borrado ---
    def test_borrar_elimina_registro_y_archivo(self):
        self.subir(self.docente, pdf(), pregunta=self.pregunta.pk)
        adjunto = ArchivoAdjunto.objects.get()
        ruta = Path(adjunto.archivo.path)
        self.assertTrue(ruta.exists())
        with self.captureOnCommitCallbacks(execute=True):
            r = self.cliente(self.docente).delete(f"/api/adjuntos/{adjunto.pk}/")
        self.assertEqual(r.status_code, 204)
        self.assertFalse(ArchivoAdjunto.objects.exists())
        self.assertFalse(ruta.exists())

    def test_ajeno_no_puede_borrar(self):
        self.subir(self.docente, pdf(), pregunta=self.pregunta.pk)
        adjunto = ArchivoAdjunto.objects.get()
        r = self.cliente(self.otro_docente).delete(f"/api/adjuntos/{adjunto.pk}/")
        self.assertEqual(r.status_code, 404)

    def test_no_se_borra_si_el_examen_esta_publicado(self):
        self.subir(self.docente, pdf(), examen=self.examen.pk)
        adjunto = ArchivoAdjunto.objects.get()
        Examen.objects.filter(pk=self.examen.pk).update(estado="publicado")
        r = self.cliente(self.docente).delete(f"/api/adjuntos/{adjunto.pk}/")
        self.assertEqual(r.status_code, 400)

    def test_sube_y_borra_quedan_en_auditoria(self):
        from apps.audit.models import Auditoria

        self.subir(self.docente, pdf(), pregunta=self.pregunta.pk)
        adjunto = ArchivoAdjunto.objects.get()
        self.cliente(self.docente).delete(f"/api/adjuntos/{adjunto.pk}/")
        acciones = set(Auditoria.objects.values_list("accion", flat=True))
        self.assertIn("subir_adjunto", acciones)
        self.assertIn("eliminar_adjunto", acciones)