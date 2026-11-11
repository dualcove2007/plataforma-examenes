import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'admin/admin_home.dart';
import 'docente/docente_home.dart';
import 'estudiante/estudiante_home.dart';

/// Cada rol entra a su propio panel.
Widget homeSegunRol(ApiService api) => api.esAdmin
    ? AdminHome(api: api)
    : api.esDocente
    ? DocenteHome(api: api)
    : EstudianteHome(api: api);
