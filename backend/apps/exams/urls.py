from rest_framework.routers import SimpleRouter

from .views import ExamenViewSet, MisExamenesViewSet

router = SimpleRouter()
router.register("examenes", ExamenViewSet, basename="examen")
router.register("mis-examenes", MisExamenesViewSet, basename="mi-examen")

urlpatterns = router.urls