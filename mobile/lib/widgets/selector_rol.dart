import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ui.dart';

/// Hoja inferior para elegir con qué rol iniciar sesión cuando la cuenta tiene
/// varios. Devuelve el nombre del rol, o `null` si la cierran sin elegir.
Future<String?> elegirRol(BuildContext context, List<String> roles) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Con qué rol quieres entrar?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tu cuenta tiene más de un rol. Elige uno para esta sesión.',
                style: TextStyle(color: Paleta.tintaSuave),
              ),
              const SizedBox(height: 16),
              for (final rol in roles) ...[
                PanelCard(
                  color: EstiloRol.de(rol).suave,
                  onTap: () => Navigator.pop(ctx, rol),
                  child: Row(
                    children: [
                      IconBadge(
                        EstiloRol.de(rol).icono,
                        fondo: Colors.white,
                        tam: 44,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          rol,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
