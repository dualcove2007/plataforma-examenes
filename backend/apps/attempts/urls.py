from rest_framework.routers import SimpleRouter

from .views import IntentoViewSet, MisResultadosViewSet, ResultadoViewSet

router = SimpleRouter()
router.register("intentos", IntentoViewSet, basename="intento")
router.register("resultados", ResultadoViewSet, basename="resultado")
router.register("mis-resultados", MisResultadosViewSet, basename="mi-resultado")

urlpatterns = router.urls