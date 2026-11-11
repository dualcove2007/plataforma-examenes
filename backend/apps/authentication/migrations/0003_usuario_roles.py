from django.db import migrations, models


def copiar_rol_principal(apps, schema_editor):
    """Cada usuario existente queda con su rol actual como único rol disponible."""
    Usuario = apps.get_model("authentication", "Usuario")
    for usuario in Usuario.objects.all():
        usuario.roles.add(usuario.rol_id)


class Migration(migrations.Migration):

    dependencies = [
        ("authentication", "0002_usuario_foto"),
    ]

    operations = [
        migrations.AddField(
            model_name="usuario",
            name="roles",
            field=models.ManyToManyField(
                blank=True, related_name="usuarios_roles", to="authentication.rol"
            ),
        ),
        migrations.RunPython(copiar_rol_principal, migrations.RunPython.noop),
    ]
