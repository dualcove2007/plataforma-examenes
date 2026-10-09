import pytest
from django.core.cache import cache


@pytest.fixture(autouse=True)
def _reiniciar_cache():
    """Los contadores del límite de intentos no deben pasar de un test a otro."""
    cache.clear()
    yield