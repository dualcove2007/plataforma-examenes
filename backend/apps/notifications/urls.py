from rest_framework.routers import SimpleRouter

from .views import NotificacionViewSet

router = SimpleRouter()
router.register("notificaciones", NotificacionViewSet, basename="notificacion")

urlpatterns = router.urls