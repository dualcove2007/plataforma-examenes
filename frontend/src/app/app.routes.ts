import { Routes } from '@angular/router';

import { authGuard, guestGuard, permisoGuard } from './core/guards/auth.guard';
import { MainLayout } from './core/layouts/main-layout/main-layout';

export const routes: Routes = [
  {
    path: 'login',
    canActivate: [guestGuard],
    loadComponent: () => import('./features/auth/login/login').then((m) => m.Login),
  },
  {
    path: '',
    component: MainLayout,
    canActivate: [authGuard],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      {
        path: 'dashboard',
        loadComponent: () => import('./features/dashboard/dashboard').then((m) => m.Dashboard),
      },
      {
        path: 'usuarios',
        canActivate: [permisoGuard('usuarios.gestionar')],
        loadComponent: () =>
          import('./features/users/usuarios-lista').then((m) => m.UsuariosLista),
      },
      {
        path: 'usuarios/nuevo',
        canActivate: [permisoGuard('usuarios.gestionar')],
        loadComponent: () => import('./features/users/usuario-form').then((m) => m.UsuarioForm),
      },
      {
        path: 'usuarios/:id/editar',
        canActivate: [permisoGuard('usuarios.gestionar')],
        loadComponent: () => import('./features/users/usuario-form').then((m) => m.UsuarioForm),
      },
    ],
  },
  { path: '**', redirectTo: '' },
];