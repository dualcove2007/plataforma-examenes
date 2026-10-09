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

      // ---- Usuarios (administrador) ----
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

      // ---- Materias (administrador) ----
      {
        path: 'materias',
        canActivate: [permisoGuard('materias.gestionar')],
        loadComponent: () =>
          import('./features/materias/materias-lista').then((m) => m.MateriasLista),
      },
      {
        path: 'materias/nueva',
        canActivate: [permisoGuard('materias.gestionar')],
        loadComponent: () => import('./features/materias/materia-form').then((m) => m.MateriaForm),
      },
      {
        path: 'materias/:id/editar',
        canActivate: [permisoGuard('materias.gestionar')],
        loadComponent: () => import('./features/materias/materia-form').then((m) => m.MateriaForm),
      },

      // ---- Bancos de preguntas (docente) ----
      {
        path: 'bancos',
        canActivate: [permisoGuard('bancos.gestionar')],
        loadComponent: () =>
          import('./features/question-bank/bancos-lista').then((m) => m.BancosLista),
      },
      {
        path: 'bancos/nuevo',
        canActivate: [permisoGuard('bancos.gestionar')],
        loadComponent: () =>
          import('./features/question-bank/banco-form').then((m) => m.BancoForm),
      },
      {
        path: 'bancos/:id/editar',
        canActivate: [permisoGuard('bancos.gestionar')],
        loadComponent: () =>
          import('./features/question-bank/banco-form').then((m) => m.BancoForm),
      },

      // ---- Preguntas de un banco (docente) ----
      {
        path: 'bancos/:bancoId/preguntas',
        canActivate: [permisoGuard('preguntas.gestionar')],
        loadComponent: () =>
          import('./features/question-bank/preguntas-lista').then((m) => m.PreguntasLista),
      },
      {
        path: 'bancos/:bancoId/preguntas/nueva',
        canActivate: [permisoGuard('preguntas.gestionar')],
        loadComponent: () =>
          import('./features/question-bank/pregunta-form').then((m) => m.PreguntaForm),
      },
      {
        path: 'bancos/:bancoId/preguntas/:id/editar',
        canActivate: [permisoGuard('preguntas.gestionar')],
        loadComponent: () =>
          import('./features/question-bank/pregunta-form').then((m) => m.PreguntaForm),
      },
      
      // ---- Exámenes (docente) ----
      {
        path: 'examenes',
        canActivate: [permisoGuard('examenes.gestionar')],
        loadComponent: () =>
          import('./features/exams/examenes-lista').then((m) => m.ExamenesLista),
      },
      {
        path: 'examenes/nuevo',
        canActivate: [permisoGuard('examenes.gestionar')],
        loadComponent: () => import('./features/exams/examen-form').then((m) => m.ExamenForm),
      },
      {
        path: 'examenes/:id/editar',
        canActivate: [permisoGuard('examenes.gestionar')],
        loadComponent: () => import('./features/exams/examen-form').then((m) => m.ExamenForm),
      },
      {
        path: 'examenes/:id',
        canActivate: [permisoGuard('examenes.gestionar')],
        loadComponent: () =>
          import('./features/exams/examen-detalle').then((m) => m.ExamenDetalle),
      },
    ],
  },
  { path: '**', redirectTo: '' },
];