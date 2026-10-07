from rest_framework.routers import SimpleRouter

from .views import BancoViewSet, MateriaViewSet, PreguntaViewSet

router = SimpleRouter()
router.register("materias", MateriaViewSet, basename="materia")
router.register("bancos", BancoViewSet, basename="banco")
router.register("preguntas", PreguntaViewSet, basename="pregunta")

urlpatterns = router.urls