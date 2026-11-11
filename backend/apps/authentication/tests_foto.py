import shutil
import tempfile

from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from .models import Usuario

PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64
MEDIA_TMP = tempfile.mkdtemp()


@override_settings(MEDIA_ROOT=MEDIA_TMP)
class FotoPerfilTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command("seed", verbosity=0)
        cls.admin = Usuario.objects.get(email="admin@demo.com")
        cls.estudiante = Usuario.objects.get(email="estudiante@demo.com")
        cls.docente = Usuario.objects.get(email="docente@demo.com")

    @classmethod
    def tearDownClass(cls):
        super().tearDownClass()
        shutil.rmtree(MEDIA_TMP, ignore_errors=True)

    def como(self, usuario):
        c = APIClient()
        c.force_authenticate(usuario)
        return c

    def archivo(self, nombre="yo.png", contenido=PNG):
        return SimpleUploadedFile(nombre, contenido, content_type="image/png")

    def test_usuario_sube_y_ve_su_foto(self):
        c = self.como(self.estudiante)
        r = c.put("/api/auth/me/foto/", {"foto": self.archivo()}, format="multipart")
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.data["foto_version"])
        self.assertEqual(c.get("/api/auth/me/foto/").status_code, 200)
        self.assertTrue(c.get("/api/auth/me/").data["foto_version"])

    def test_sin_foto_devuelve_404(self):
        self.assertEqual(self.como(self.estudiante).get("/api/auth/me/foto/").status_code, 404)

    def test_rechaza_pdf_y_contenido_falso(self):
        c = self.como(self.estudiante)
        falso = self.archivo("yo.png", b"esto no es una imagen")
        self.assertEqual(c.put("/api/auth/me/foto/", {"foto": falso}, format="multipart").status_code, 400)
        pdf = SimpleUploadedFile("a.pdf", b"%PDF-1.4 x", content_type="application/pdf")
        self.assertEqual(c.put("/api/auth/me/foto/", {"foto": pdf}, format="multipart").status_code, 400)

    def test_quitar_foto(self):
        c = self.como(self.estudiante)
        c.put("/api/auth/me/foto/", {"foto": self.archivo()}, format="multipart")
        self.assertEqual(c.delete("/api/auth/me/foto/").status_code, 204)
        self.assertEqual(c.get("/api/auth/me/foto/").status_code, 404)

    def test_admin_pone_foto_a_otro_usuario(self):
        r = self.como(self.admin).put(
            f"/api/usuarios/{self.estudiante.pk}/foto/", {"foto": self.archivo()}, format="multipart"
        )
        self.assertEqual(r.status_code, 200)
        self.estudiante.refresh_from_db()
        self.assertTrue(self.estudiante.foto)

    def test_docente_no_gestiona_fotos_ajenas(self):
        r = self.como(self.docente).put(
            f"/api/usuarios/{self.estudiante.pk}/foto/", {"foto": self.archivo()}, format="multipart"
        )
        self.assertEqual(r.status_code, 403)
