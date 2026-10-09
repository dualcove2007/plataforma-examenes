from datetime import timedelta

from django.core.management import call_command
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken

from apps.audit.models import Auditoria

from .models import RefreshToken, Usuario

PASSWORD = "Demo12345*"
MSG_LOGIN = "Email o contraseña incorrectos."


class AutenticacionTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command("seed", verbosity=0)
        cls.docente = Usuario.objects.get(email="docente@demo.com")
        cls.estudiante = Usuario.objects.get(email="estudiante@demo.com")

    # ---------- helpers ----------
    def login(self, email="docente@demo.com", password=PASSWORD):
        return APIClient().post(
            "/api/auth/login/", {"email": email, "password": password}, format="json"
        )

    def refrescar(self, refresh):
        return APIClient().post("/api/auth/refresh/", {"refresh": refresh}, format="json")

    def con_token(self, access):
        cliente = APIClient()
        cliente.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
        return cliente

    # ---------- login ----------
    def test_login_correcto_devuelve_tokens_y_usuario(self):
        r = self.login()
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.data["access"])
        self.assertTrue(r.data["refresh"])
        self.assertEqual(r.data["usuario"]["email"], "docente@demo.com")
        self.assertEqual(r.data["usuario"]["rol"], "Docente")
        self.assertNotIn("password", r.data["usuario"])

    def test_login_actualiza_last_login_y_audita(self):
        self.assertIsNone(self.docente.last_login)
        self.login()
        self.docente.refresh_from_db()
        self.assertIsNotNone(self.docente.last_login)
        self.assertTrue(
            Auditoria.objects.filter(accion="login", usuario=self.docente).exists()
        )

    def test_login_password_incorrecta(self):
        r = self.login(password="otra-clave")
        self.assertEqual(r.status_code, 401)
        self.assertEqual(r.data["error"]["codigo"], 401)
        self.assertEqual(r.data["error"]["mensaje"], MSG_LOGIN)
        fallo = Auditoria.objects.get(accion="login_fallido")
        self.assertEqual(fallo.detalle["email"], "docente@demo.com")

    def test_login_email_inexistente_da_el_mismo_mensaje(self):
        # No se revela si el correo existe o no
        r = self.login(email="nadie@demo.com")
        self.assertEqual(r.status_code, 401)
        self.assertEqual(r.data["error"]["mensaje"], MSG_LOGIN)

    def test_login_usuario_inactivo(self):
        Usuario.objects.filter(pk=self.docente.pk).update(activo=False)
        self.assertEqual(self.login().status_code, 401)

    def test_login_datos_invalidos(self):
        cliente = APIClient()
        r = cliente.post("/api/auth/login/", {"email": "docente@demo.com"}, format="json")
        self.assertEqual(r.status_code, 400)
        self.assertIn("password", r.data["error"]["detalles"])
        r = cliente.post(
            "/api/auth/login/", {"email": "no-es-correo", "password": "x"}, format="json"
        )
        self.assertEqual(r.status_code, 400)
        self.assertIn("email", r.data["error"]["detalles"])

    def test_access_token_lleva_el_rol(self):
        access = self.login().data["access"]
        self.assertEqual(AccessToken(access)["rol"], "Docente")

    def test_refresh_se_guarda_hasheado(self):
        refresh = self.login().data["refresh"]
        self.assertEqual(RefreshToken.objects.filter(usuario=self.docente).count(), 1)
        self.assertFalse(RefreshToken.objects.filter(token_hash=refresh).exists())
        
    def test_login_se_limita_por_correo(self):
        for _ in range(5):
            self.assertEqual(self.login(password="mala").status_code, 401)
        r = self.login(password="mala")
        self.assertEqual(r.status_code, 429)
        self.assertIn("Demasiados intentos", r.data["error"]["mensaje"])
        # Mientras dure el bloqueo, ni la clave correcta entra
        self.assertEqual(self.login().status_code, 429)

    def test_login_se_limita_por_ip(self):
        for i in range(20):
            self.assertEqual(self.login(email=f"nadie{i}@demo.com").status_code, 401)
        self.assertEqual(self.login(email="otro@demo.com").status_code, 429)

    def test_cambiar_password_revoca_los_refresh_tokens(self):
        refresh = self.login().data["refresh"]
        admin = self.con_token(self.login("admin@demo.com").data["access"])
        r = admin.patch(
            f"/api/usuarios/{self.docente.pk}/",
            {"password": "NuevaClave987*"},
            format="json",
        )
        self.assertEqual(r.status_code, 200)
        self.assertEqual(self.refrescar(refresh).status_code, 401)

    def test_admin_no_puede_cambiar_su_propio_rol(self):
        admin_user = Usuario.objects.get(email="admin@demo.com")
        admin = self.con_token(self.login("admin@demo.com").data["access"])
        r = admin.patch(
            f"/api/usuarios/{admin_user.pk}/",
            {"rol": self.docente.rol_id},
            format="json",
        )
        self.assertEqual(r.status_code, 400)

    # ---------- refresh ----------
    def test_refresh_devuelve_tokens_nuevos(self):
        refresh = self.login().data["refresh"]
        r = self.refrescar(refresh)
        self.assertEqual(r.status_code, 200)
        self.assertNotEqual(r.data["refresh"], refresh)
        self.assertEqual(self.con_token(r.data["access"]).get("/api/auth/me/").status_code, 200)

    def test_refresh_rota_y_no_se_puede_reusar(self):
        viejo = self.login().data["refresh"]
        nuevo = self.refrescar(viejo).data["refresh"]
        reuso = self.refrescar(viejo)
        self.assertEqual(reuso.status_code, 401)
        self.assertEqual(self.refrescar(nuevo).status_code, 200)

    def test_refresh_con_token_basura(self):
        self.assertEqual(self.refrescar("esto.no.es.un.jwt").status_code, 401)

    def test_refresh_rechaza_un_access_token(self):
        access = self.login().data["access"]
        self.assertEqual(self.refrescar(access).status_code, 401)

    def test_refresh_expirado_en_base_de_datos(self):
        refresh = self.login().data["refresh"]
        RefreshToken.objects.update(fecha_expiracion=timezone.now() - timedelta(minutes=1))
        self.assertEqual(self.refrescar(refresh).status_code, 401)

    def test_refresh_de_usuario_desactivado(self):
        refresh = self.login().data["refresh"]
        Usuario.objects.filter(pk=self.docente.pk).update(activo=False)
        self.assertEqual(self.refrescar(refresh).status_code, 401)

    def test_refresh_sin_campo(self):
        r = APIClient().post("/api/auth/refresh/", {}, format="json")
        self.assertEqual(r.status_code, 400)

    # ---------- logout ----------
    def test_logout_revoca_el_refresh(self):
        datos = self.login().data
        r = self.con_token(datos["access"]).post(
            "/api/auth/logout/", {"refresh": datos["refresh"]}, format="json"
        )
        self.assertEqual(r.status_code, 204)
        self.assertEqual(self.refrescar(datos["refresh"]).status_code, 401)
        self.assertTrue(
            Auditoria.objects.filter(accion="logout", usuario=self.docente).exists()
        )

    def test_logout_requiere_autenticacion(self):
        refresh = self.login().data["refresh"]
        r = APIClient().post("/api/auth/logout/", {"refresh": refresh}, format="json")
        self.assertEqual(r.status_code, 401)
        self.assertEqual(self.refrescar(refresh).status_code, 200)

    def test_logout_no_puede_revocar_el_token_de_otro_usuario(self):
        ajeno = self.login("estudiante@demo.com").data["refresh"]
        propio = self.login("docente@demo.com").data["access"]
        r = self.con_token(propio).post("/api/auth/logout/", {"refresh": ajeno}, format="json")
        self.assertEqual(r.status_code, 204)
        # El token del estudiante sigue vivo: el docente no pudo revocarlo
        self.assertEqual(self.refrescar(ajeno).status_code, 200)

    # ---------- me ----------
    def test_me_devuelve_usuario_con_sus_permisos(self):
        access = self.login("estudiante@demo.com").data["access"]
        r = self.con_token(access).get("/api/auth/me/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data["email"], "estudiante@demo.com")
        self.assertEqual(r.data["rol"], "Estudiante")
        self.assertEqual(
            sorted(r.data["permisos"]), ["examenes.rendir", "resultados.ver_propios"]
        )

    def test_me_sin_token(self):
        r = APIClient().get("/api/auth/me/")
        self.assertEqual(r.status_code, 401)
        self.assertEqual(r.data["error"]["codigo"], 401)

    def test_me_con_token_invalido(self):
        self.assertEqual(self.con_token("basura").get("/api/auth/me/").status_code, 401)

    def test_me_rechaza_un_refresh_usado_como_access(self):
        refresh = self.login().data["refresh"]
        self.assertEqual(self.con_token(refresh).get("/api/auth/me/").status_code, 401)

    def test_me_con_access_expirado(self):
        token = AccessToken.for_user(self.docente)
        token.set_exp(lifetime=-timedelta(seconds=10))
        self.assertEqual(self.con_token(str(token)).get("/api/auth/me/").status_code, 401)

    def test_me_con_usuario_desactivado_despues_del_login(self):
        access = self.login().data["access"]
        Usuario.objects.filter(pk=self.docente.pk).update(activo=False)
        self.assertEqual(self.con_token(access).get("/api/auth/me/").status_code, 401)