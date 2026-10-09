import { Component, inject } from '@angular/core';

import { AuthService } from '../../core/services/auth.service';

/** Marcador de posición: aquí irán las estadísticas de /api/reportes/estadisticas/. */
@Component({
  selector: 'app-dashboard',
  template: `
    @if (auth.usuario(); as u) {
      <h2>Hola, {{ u.nombre }}</h2>
      <p>Entraste como <strong>{{ u.rol }}</strong>.</p>
      <details>
        <summary>Permisos de tu rol ({{ u.permisos.length }})</summary>
        <ul>
          @for (p of u.permisos; track p) {
            <li>{{ p }}</li>
          }
        </ul>
      </details>
    }
  `,
})
export class Dashboard {
  protected readonly auth = inject(AuthService);
}
