from rest_framework.routers import SimpleRouter

from .views import ArchivoAdjuntoViewSet

router = SimpleRouter()
router.register("adjuntos", ArchivoAdjuntoViewSet, basename="adjunto")

urlpatterns = router.urls