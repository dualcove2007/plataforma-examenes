from django.core.management import call_command
from django.test import TestCase
from rest_framework.test import APIClient

from .models import Permiso, RefreshToken, Rol, Usuario
from .services import emitir_tokens

PASSWORD = "Demo12345*"

# ruta, administrador, docente, estudiante
MATRIZ = [
    ("/api/usuarios/", 200, 403, 403),
    ("/api/roles/", 200, 403, 403),
    ("/api/permisos/", 200, 403, 403),
    ("/api/auditoria/", 200, 403, 403),
    ("/api/historial/", 200, 403, 403),
    ("/api/historial-estados/", 200, 403, 403),
    ("/api/resultados/", 200, 200, 403),
    ("/api/mis-resultados/", 403, 403, 200),
    ("/api/reportes/estadisticas/", 200, 200, 403),
]


class BaseApi(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command("seed", verbosity=0)
        cls.admin = Usuario.objects.get(email="admin@demo.com")
        cls.docente = Usuario.objects.get(email="docente@demo.com")
        cls.estudiante = Usuario.objects.get(email="estudiante@demo.com")
        cls.rol_admin = Rol.objects.get(nombre=Rol.ADMINISTRADOR)
        cls.rol_docente = Rol.objects.get(nombre=Rol.DOCENTE)
        cls.rol_estudiante = Rol.objects.get(nombre=Rol.ESTUDIANTE)

    def como(self, usuario):
        cliente = APIClient()
        if usuario:
            cliente.force_authenticate(usuario)
        return cliente


class PermisosPorRolTests(BaseApi):
    def test_matriz_de_acceso_por_rol(self):
        for ruta, admin, docente, estudiante in MATRIZ:
            for usuario, esperado in (
                (self.admin, admin),
                (self.docente, docente),
                (self.estudiante, estudiante),
            ):
                with self.subTest(ruta=ruta, rol=usuario.rol.nombre):
                    self.assertEqual(self.como(usuario).get(ruta).status_code, esperado)

    def test_sin_autenticar_todo_da_401(self):
        for ruta, *_ in MATRIZ:
            with self.subTest(ruta=ruta):
                self.assertEqual(self.como(None).get(ruta).status_code, 401)

    def test_usuario_inactivo_pierde_los_permisos(self):
        self.assertTrue(self.admin.tiene_permiso("usuarios.gestionar"))
        Usuario.objects.filter(pk=self.admin.pk).update(activo=False)
        self.admin.refresh_from_db()
        self.assertFalse(self.admin.tiene_permiso("usuarios.gestionar"))

    def test_error_403_usa_el_formato_centralizado(self):
        r = self.como(self.estudiante).get("/api/usuarios/")
        self.assertEqual(r.data["error"]["codigo"], 403)
        self.assertTrue(r.data["error"]["mensaje"])


class GestionUsuariosTests(BaseApi):
    def test_admin_crea_usuario_y_este_puede_entrar(self):
        r = self.como(self.admin).post(
            "/api/usuarios/",
            {
                "nombre": "Nuevo Estudiante",
                "email": "nuevo@demo.com",
                "password": "Clave-Segura-2026",
                "rol": self.rol_estudiante.id,
            },
            format="json",
        )
        self.assertEqual(r.status_code, 201)
        self.assertNotIn("password", r.data)
        nuevo = Usuario.objects.get(email="nuevo@demo.com")
        self.assertNotEqual(nuevo.password, "Clave-Segura-2026")  # guardada con hash
        self.assertTrue(nuevo.check_password("Clave-Segura-2026"))
        login = APIClient().post(
            "/api/auth/login/",
            {"email": "nuevo@demo.com", "password": "Clave-Segura-2026"},
            format="json",
        )
        self.assertEqual(login.status_code, 200)

    def test_docente_no_puede_crear_usuarios(self):
        r = self.como(self.docente).post(
            "/api/usuarios/",
            {"nombre": "X", "email": "x@demo.com", "password": "Clave-Segura-2026",
             "rol": self.rol_estudiante.id},
            format="json",
        )
        self.assertEqual(r.status_code, 403)

    def test_contrasena_debil_es_rechazada(self):
        for clave in ("12345678", "abc", "password"):
            with self.subTest(clave=clave):
                r = self.como(self.admin).post(
                    "/api/usuarios/",
                    {"nombre": "X", "email": "x@demo.com", "password": clave,
                     "rol": self.rol_estudiante.id},
                    format="json",
                )
                self.assertEqual(r.status_code, 400)
        self.assertFalse(Usuario.objects.filter(email="x@demo.com").exists())

    def test_contrasena_obligatoria_al_crear(self):
        r = self.como(self.admin).post(
            "/api/usuarios/",
            {"nombre": "X", "email": "x@demo.com", "rol": self.rol_estudiante.id},
            format="json",
        )
        self.assertEqual(r.status_code, 400)
        self.assertIn("password", r.data["error"]["detalles"])

    def test_email_duplicado(self):
        r = self.como(self.admin).post(
            "/api/usuarios/",
            {"nombre": "Otro", "email": "docente@demo.com", "password": "Clave-Segura-2026",
             "rol": self.rol_docente.id},
            format="json",
        )
        self.assertEqual(r.status_code, 400)
        self.assertIn("email", r.data["error"]["detalles"])

    def test_no_puede_desactivarse_a_si_mismo(self):
        cliente = self.como(self.admin)
        self.assertEqual(cliente.delete(f"/api/usuarios/{self.admin.pk}/").status_code, 400)
        r = cliente.patch(f"/api/usuarios/{self.admin.pk}/", {"activo": False}, format="json")
        self.assertEqual(r.status_code, 400)
        self.admin.refresh_from_db()
        self.assertTrue(self.admin.activo)

    def test_eliminar_desactiva_y_revoca_sesiones(self):
        emitir_tokens(self.estudiante)
        r = self.como(self.admin).delete(f"/api/usuarios/{self.estudiante.pk}/")
        self.assertEqual(r.status_code, 204)
        self.estudiante.refresh_from_db()  # sigue existiendo, solo inactivo
        self.assertFalse(self.estudiante.activo)
        self.assertFalse(
            RefreshToken.objects.filter(usuario=self.estudiante, revocado=False).exists()
        )

    def test_filtrar_por_rol_y_buscar(self):
        cliente = self.como(self.admin)
        r = cliente.get("/api/usuarios/", {"rol": self.rol_estudiante.id})
        self.assertEqual(r.data["count"], 1)
        self.assertEqual(r.data["results"][0]["email"], "estudiante@demo.com")
        r = cliente.get("/api/usuarios/", {"search": "docente"})
        self.assertEqual([u["email"] for u in r.data["results"]], ["docente@demo.com"])

    def test_paginacion_de_10_en_10(self):
        for i in range(12):
            Usuario.objects.create_user(
                f"u{i}@demo.com", f"Usuario {i}", PASSWORD, rol=self.rol_estudiante
            )
        r = self.como(self.admin).get("/api/usuarios/")
        self.assertEqual(r.data["count"], 15)
        self.assertEqual(len(r.data["results"]), 10)
        self.assertIsNotNone(r.data["next"])
        r2 = self.como(self.admin).get("/api/usuarios/", {"page": 2})
        self.assertEqual(len(r2.data["results"]), 5)

    def test_ordenar_por_email(self):
        r = self.como(self.admin).get("/api/usuarios/", {"ordering": "-email"})
        emails = [u["email"] for u in r.data["results"]]
        self.assertEqual(emails, sorted(emails, reverse=True))


class GestionRolesTests(BaseApi):
    def ids(self, *codigos):
        return list(Permiso.objects.filter(nombre__in=codigos).values_list("id", flat=True))

    def test_admin_actualiza_permisos_de_un_rol(self):
        nuevos = self.ids("bancos.gestionar", "reportes.ver")
        r = self.como(self.admin).patch(
            f"/api/roles/{self.rol_docente.id}/", {"permisos": nuevos}, format="json"
        )
        self.assertEqual(r.status_code, 200)
        self.assertEqual(
            set(self.rol_docente.permisos.values_list("nombre", flat=True)),
            {"bancos.gestionar", "reportes.ver"},
        )

    def test_el_administrador_conserva_sus_permisos_criticos(self):
        r = self.como(self.admin).patch(
            f"/api/roles/{self.rol_admin.id}/",
            {"permisos": self.ids("materias.gestionar")},
            format="json",
        )
        self.assertEqual(r.status_code, 400)
        self.assertTrue(self.admin.tiene_permiso("roles.gestionar"))

    def test_el_nombre_del_rol_no_se_puede_cambiar(self):
        r = self.como(self.admin).patch(
            f"/api/roles/{self.rol_docente.id}/", {"nombre": "Otro"}, format="json"
        )
        self.assertEqual(r.status_code, 200)
        self.rol_docente.refresh_from_db()
        self.assertEqual(self.rol_docente.nombre, Rol.DOCENTE)

    def test_docente_no_gestiona_roles(self):
        r = self.como(self.docente).patch(
            f"/api/roles/{self.rol_docente.id}/", {"descripcion": "x"}, format="json"
        )
        self.assertEqual(r.status_code, 403)