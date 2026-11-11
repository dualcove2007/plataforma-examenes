from django.core.management import call_command
from django.test import TestCase
from rest_framework.test import APIClient

from .models import Rol, Usuario

PASSWORD = "Demo12345*"


class RolesMultiplesTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command("seed", verbosity=0)
        cls.admin = Usuario.objects.get(email="admin@demo.com")
        cls.docente_rol = Rol.objects.get(nombre=Rol.DOCENTE)
        cls.admin_rol = Rol.objects.get(nombre=Rol.ADMINISTRADOR)
        cls.estudiante_rol = Rol.objects.get(nombre=Rol.ESTUDIANTE)
        # Cuenta con dos roles: Docente (principal) y Estudiante.
        cls.doble = Usuario.objects.create_user(
            "doble@demo.com", "Doble Rol", PASSWORD, rol=cls.docente_rol
        )
        cls.doble.roles.add(cls.estudiante_rol)

    # ---------- helpers ----------
    def login(self, email="doble@demo.com", **extra):
        return APIClient().post(
            "/api/auth/login/",
            {"email": email, "password": PASSWORD, **extra},
            format="json",
        )

    def con_token(self, access):
        cliente = APIClient()
        cliente.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
        return cliente

    # ---------- login ----------
    def test_un_solo_rol_entra_directo(self):
        r = self.login("docente@demo.com")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data["usuario"]["rol"], "Docente")
        self.assertEqual(r.data["usuario"]["roles"], ["Docente"])

    def test_varios_roles_sin_elegir_pide_el_rol_y_no_da_tokens(self):
        r = self.login()
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.data["requiere_rol"])
        self.assertCountEqual(r.data["roles"], ["Docente", "Estudiante"])
        self.assertNotIn("access", r.data)
        self.assertNotIn("refresh", r.data)

    def test_contrasena_incorrecta_no_revela_roles(self):
        r = APIClient().post(
            "/api/auth/login/",
            {"email": "doble@demo.com", "password": "mala"},
            format="json",
        )
        self.assertEqual(r.status_code, 401)
        self.assertNotIn("roles", r.data)

    def test_elegir_rol_entra_con_ese_rol(self):
        r = self.login(rol="Estudiante")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data["usuario"]["rol"], "Estudiante")
        self.assertCountEqual(r.data["usuario"]["roles"], ["Docente", "Estudiante"])

    def test_rol_que_no_tiene_se_rechaza(self):
        r = self.login(rol="Administrador")
        self.assertEqual(r.status_code, 401)

    def test_el_rol_elegido_no_cambia_el_rol_principal_guardado(self):
        self.login(rol="Estudiante")
        self.doble.refresh_from_db()
        self.assertEqual(self.doble.rol, self.docente_rol)

    # ---------- sesión con el rol elegido ----------
    def test_me_devuelve_el_rol_de_la_sesion(self):
        access = self.login(rol="Estudiante").data["access"]
        me = self.con_token(access).get("/api/auth/me/")
        self.assertEqual(me.data["rol"], "Estudiante")

    def test_permisos_dependen_del_rol_elegido(self):
        # Como estudiante no puede ver la lista de usuarios; el admin sí.
        access = self.login(rol="Estudiante").data["access"]
        self.assertEqual(self.con_token(access).get("/api/usuarios/").status_code, 403)

    def test_refresh_conserva_el_rol_elegido(self):
        refresh = self.login(rol="Estudiante").data["refresh"]
        r = APIClient().post("/api/auth/refresh/", {"refresh": refresh}, format="json")
        self.assertEqual(r.status_code, 200)
        me = self.con_token(r.data["access"]).get("/api/auth/me/")
        self.assertEqual(me.data["rol"], "Estudiante")

    def test_si_le_quitan_el_rol_la_sesion_vuelve_al_principal(self):
        refresh = self.login(rol="Estudiante").data["refresh"]
        self.doble.roles.remove(self.estudiante_rol)
        r = APIClient().post("/api/auth/refresh/", {"refresh": refresh}, format="json")
        me = self.con_token(r.data["access"]).get("/api/auth/me/")
        self.assertEqual(me.data["rol"], "Docente")

    # ---------- administración de roles de un usuario ----------
    def admin_client(self):
        access = self.login("admin@demo.com").data["access"]
        return self.con_token(access)

    def test_admin_agrega_un_rol_a_un_usuario(self):
        estudiante = Usuario.objects.get(email="estudiante@demo.com")
        r = self.admin_client().patch(
            f"/api/usuarios/{estudiante.pk}/",
            {"roles": [self.estudiante_rol.pk, self.docente_rol.pk]},
            format="json",
        )
        self.assertEqual(r.status_code, 200)
        self.assertCountEqual(
            [x.nombre for x in estudiante.roles_disponibles()],
            ["Estudiante", "Docente"],
        )
        # Ahora le pide elegir el rol al iniciar sesión.
        self.assertTrue(self.login("estudiante@demo.com").data["requiere_rol"])

    def test_cambiar_el_principal_lo_deja_en_los_roles(self):
        estudiante = Usuario.objects.get(email="estudiante@demo.com")
        self.admin_client().patch(
            f"/api/usuarios/{estudiante.pk}/",
            {"rol": self.docente_rol.pk},
            format="json",
        )
        self.assertCountEqual(
            [x.nombre for x in estudiante.roles_disponibles()],
            ["Estudiante", "Docente"],
        )

    def test_admin_crea_usuario_con_varios_roles(self):
        r = self.admin_client().post(
            "/api/usuarios/",
            {
                "nombre": "Nuevo",
                "email": "nuevo@demo.com",
                "password": "Clave12*ab",
                "rol": self.docente_rol.pk,
                "roles": [self.docente_rol.pk, self.admin_rol.pk],
            },
            format="json",
        )
        self.assertEqual(r.status_code, 201, r.data)
        nuevo = Usuario.objects.get(email="nuevo@demo.com")
        self.assertCountEqual(
            [x.nombre for x in nuevo.roles_disponibles()],
            ["Docente", "Administrador"],
        )

    def test_admin_no_puede_quitarse_roles_a_si_mismo(self):
        self.admin.roles.add(self.docente_rol)
        access = self.login("admin@demo.com", rol="Administrador").data["access"]
        r = self.con_token(access).patch(
            f"/api/usuarios/{self.admin.pk}/",
            {"roles": [self.admin_rol.pk]},
            format="json",
        )
        self.assertEqual(r.status_code, 400)

    def test_filtro_por_rol_incluye_roles_adicionales(self):
        r = self.admin_client().get(f"/api/usuarios/?rol={self.estudiante_rol.pk}")
        emails = [u["email"] for u in r.data["results"]]
        self.assertIn("doble@demo.com", emails)

    def test_lista_de_estudiantes_asignables_incluye_roles_adicionales(self):
        self.assertTrue(
            Usuario.objects.filter(
                roles__nombre=Rol.ESTUDIANTE, email="doble@demo.com"
            ).exists()
        )
