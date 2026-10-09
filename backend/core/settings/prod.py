from .base import *  # noqa

DEBUG = False

# Todo lo que cambia entre entornos se lee de variables de entorno.
ALLOWED_HOSTS = env.list("ALLOWED_HOSTS", default=["localhost", "127.0.0.1"])
CORS_ALLOWED_ORIGINS = env.list(
    "CORS_ALLOWED_ORIGINS", default=["http://localhost:4200"]
)
CSRF_TRUSTED_ORIGINS = env.list("CSRF_TRUSTED_ORIGINS", default=[])

# Estáticos del admin servidos por WhiteNoise.
STATIC_ROOT = BASE_DIR / "staticfiles"
MIDDLEWARE = list(MIDDLEWARE)  # noqa: F405
MIDDLEWARE.insert(2, "whitenoise.middleware.WhiteNoiseMiddleware")