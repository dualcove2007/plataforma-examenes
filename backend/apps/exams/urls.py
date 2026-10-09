from rest_framework.routers import SimpleRouter

from .views import EstudianteViewSet, ExamenViewSet, MisExamenesViewSet

router = SimpleRouter()
router.register("examenes", ExamenViewSet, basename="examen")
router.register("mis-examenes", MisExamenesViewSet, basename="mi-examen")
router.register("estudiantes", EstudianteViewSet, basename="estudiante")

urlpatterns = router.urls