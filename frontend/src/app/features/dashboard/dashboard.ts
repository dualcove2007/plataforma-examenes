import { KeyValuePipe } from '@angular/common';
import { Component, inject, signal } from '@angular/core';

import { AuthService } from '../../core/services/auth.service';
import { mensajeError } from '../../core/utils/api-error';
import { Estadisticas, ReportesService } from './reportes.service';

@Component({
  selector: 'app-dashboard',
  imports: [KeyValuePipe],
  template: `
    @if (auth.usuario(); as u) {
      <h2>Hola, {{ u.nombre }}</h2>
      <p>Entraste como <strong>{{ u.rol }}</strong>.</p>
    }

    @if (auth.tienePermiso('reportes.ver')) {
      <h3>Estadísticas</h3>

      @if (error()) {
        <p role="alert">{{ error() }}</p>
      }

      @if (cargando()) {
        <p role="status">Cargando estadísticas…</p>
      } @else if (est(); as e) {
        <section aria-label="Resumen">
          <ul>
            <li>Asignaciones: <strong>{{ e.asignaciones }}</strong></li>
            <li>Nota mínima para aprobar: <strong>{{ e.nota_minima }}</strong></li>
          </ul>
        </section>

        <section aria-label="Exámenes">
          <h4>Exámenes</h4>
          <ul>
            @for (x of e.examenes | keyvalue; track x.key) {
              <li>{{ x.key }}: <strong>{{ x.value }}</strong></li>
            }
          </ul>
        </section>

        <section aria-label="Intentos">
          <h4>Intentos</h4>
          <ul>
            @for (x of e.intentos | keyvalue; track x.key) {
              <li>{{ x.key }}: <strong>{{ x.value }}</strong></li>
            }
          </ul>
        </section>

        <section aria-label="Resultados">
          <h4>Resultados</h4>
          <ul>
            <li>Total: <strong>{{ e.resultados.total }}</strong></li>
            <li>Revisados: <strong>{{ e.resultados.revisados }}</strong></li>
            <li>Pendientes de revisión: <strong>{{ e.resultados.pendientes_revision }}</strong></li>
            <li>Promedio de nota: <strong>{{ e.resultados.promedio_nota ?? '—' }}</strong></li>
            <li>Aprobados: <strong>{{ e.resultados.aprobados }}</strong></li>
            <li>Reprobados: <strong>{{ e.resultados.reprobados }}</strong></li>
            <li>
              Tasa de aprobación:
              <strong>
                {{ e.resultados.tasa_aprobacion === null ? '—' : e.resultados.tasa_aprobacion + ' %' }}
              </strong>
            </li>
          </ul>
        </section>

        <section aria-label="Exámenes recientes">
          <h4>Exámenes recientes</h4>
          @if (e.por_examen.length === 0) {
            <p>Todavía no hay exámenes.</p>
          } @else {
            <table>
              <thead>
                <tr>
                  <th>Examen</th>
                  <th>Estado</th>
                  <th>Asignados</th>
                  <th>Presentaron</th>
                  <th>Revisados</th>
                  <th>Promedio</th>
                  <th>Aprobados</th>
                  <th>Reprobados</th>
                  <th>Excel</th>
                </tr>
              </thead>
              <tbody>
                @for (x of e.por_examen; track x.id) {
                  <tr>
                    <td>{{ x.titulo }}</td>
                    <td>{{ x.estado }}</td>
                    <td>{{ x.asignados }}</td>
                    <td>{{ x.presentaron }}</td>
                    <td>{{ x.revisados }}</td>
                    <td>{{ x.promedio_nota ?? '—' }}</td>
                    <td>{{ x.aprobados }}</td>
                    <td>{{ x.reprobados }}</td>
                    <td>
                      <button type="button" (click)="descargarNotas(x.id)">Descargar</button>
                    </td>
                  </tr>
                }
              </tbody>
            </table>
          }
        </section>
      }
    }

    @if (u(); as usuario) {
      <details>
        <summary>Permisos de tu rol ({{ usuario.permisos.length }})</summary>
        <ul>
          @for (p of usuario.permisos; track p) {
            <li>{{ p }}</li>
          }
        </ul>
      </details>
    }
  `,
})
export class Dashboard {
  protected readonly auth = inject(AuthService);
  private readonly reportes = inject(ReportesService);

  protected readonly u = this.auth.usuario;
  protected readonly est = signal<Estadisticas | null>(null);
  protected readonly cargando = signal(false);
  protected readonly error = signal('');

  constructor() {
    if (this.auth.tienePermiso('reportes.ver')) {
      this.cargar();
    }
  }

  private cargar(): void {
    this.cargando.set(true);
    this.error.set('');
    this.reportes.estadisticas().subscribe({
      next: (datos) => {
        this.est.set(datos);
        this.cargando.set(false);
      },
      error: (err) => {
        this.error.set(mensajeError(err));
        this.cargando.set(false);
      },
    });
  }

  protected descargarNotas(examenId: number): void {
    this.error.set('');
    this.reportes.descargarNotas(examenId).subscribe({
      next: (blob) => {
        const url = URL.createObjectURL(blob);
        const enlace = document.createElement('a');
        enlace.href = url;
        enlace.download = `notas_examen_${examenId}.xlsx`;
        enlace.click();
        URL.revokeObjectURL(url);
      },
      error: () => this.error.set('No se pudo descargar el Excel de notas.'),
    });
  }
}