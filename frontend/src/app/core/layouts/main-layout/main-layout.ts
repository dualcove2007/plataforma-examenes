import { Component, computed, inject } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';

import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-main-layout',
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  templateUrl: './main-layout.html',
  styleUrl: './main-layout.scss',
})
export class MainLayout {
  protected readonly auth = inject(AuthService);

  // Se irá ampliando por rol a medida que se construyan los módulos.
  protected readonly enlaces = computed(() =>
    [
      { ruta: '/dashboard', texto: 'Inicio', visible: true },
      {
        ruta: '/usuarios',
        texto: 'Usuarios',
        visible: this.auth.tienePermiso('usuarios.gestionar'),
      },
    ].filter((e) => e.visible),
  );

  salir(): void {
    this.auth.logout();
  }
}