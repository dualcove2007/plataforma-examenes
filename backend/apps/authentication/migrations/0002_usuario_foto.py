import apps.authentication.models
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("authentication", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="usuario",
            name="foto",
            field=models.FileField(
                blank=True,
                max_length=255,
                null=True,
                upload_to=apps.authentication.models.ruta_foto,
            ),
        ),
    ]
