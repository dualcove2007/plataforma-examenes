from rest_framework.routers import SimpleRouter

from .views import AuditoriaViewSet, HistorialCambiosViewSet, HistorialEstadoViewSet

router = SimpleRouter()
router.register("auditoria", AuditoriaViewSet, basename="auditoria")
router.register("historial", HistorialCambiosViewSet, basename="historial-cambios")
router.register("historial-estados", HistorialEstadoViewSet, basename="historial-estado")

urlpatterns = router.urls