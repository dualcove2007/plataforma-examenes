from django.contrib import admin

from .models import Permiso, Rol, RolPermiso, Usuario

admin.site.register(Permiso)
admin.site.register(Rol)
admin.site.register(RolPermiso)
admin.site.register(Usuario)