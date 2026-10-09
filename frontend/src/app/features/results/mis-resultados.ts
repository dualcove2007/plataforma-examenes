import { Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { mensajeError } from '../../core/utils/api-error';
import { guardarArchivo } from '../../core/utils/descargar';
import { MisResultadosService } from './mis-resultados.service';
import { ETIQUETA_REVISION, Resultado } from './resultados.service';

const TAMANO_PAGINA = 10;

@Component({
  selector: 'app-mis-resultados',
  imports: [RouterLink],
  template: `
    <h2>Mis resultados</h2>

    @if (error()) {
      <p role="alert">{{ error() }}</p>
    }

    @if (cargando()) {
      <p>Cargando…</p>
    } @else if (resultados().length === 0) {
      <p>Aún no tienes resultados.</p>
    } @else {
      <table>
        <thead>
          <tr>
            <th>Examen</th><th>Intento</th><th>Puntaje</th><th>Nota</th>
            <th>Revisión</th><th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          @for (r of resultados(); track r.id) {
            <tr>
              <td>{{ r.examen_titulo }}</td>
              <td>{{ r.numero_intento }}</td>
              <td>
                {{ r.puntaje_total !== null ? r.puntaje_total + ' / ' + r.puntaje_maximo : '—' }}
              </td>
              <td>{{ r.nota_final ?? '—' }}</td>
              <td>{{ etiqueta[r.estado_revision] }}</td>
              <td>
                <a [routerLink]="['/mis-resultados', r.id]">Ver detalle</a>
                @if (r.estado_revision === 'revisado') {
                  <button type="button" (click)="constancia(r)">Constancia PDF</button>
                }
              </td>
            </tr>
          }
        </tbody>
      </table>

      <nav aria-label="Paginación">
        <button type="button" [disabled]="pagina() <= 1" (click)="irA(pagina() - 1)">Anterior</button>
        <span>Página {{ pagina() }} de {{ totalPaginas() }} ({{ total() }} resultados)</span>
        <button type="button" [disabled]="pagina() >= totalPaginas()" (click)="irA(pagina() + 1)">Siguiente</button>
      </nav>
    }
  `,
})
export class MisResultados {
  private readonly api = inject(MisResultadosService);

  protected readonly etiqueta = ETIQUETA_REVISION;

  protected readonly resultados = signal<Resultado[]>([]);
  protected readonly total = signal(0);
  protected readonly pagina = signal(1);
  protected readonly cargando = signal(false);
  protected readonly error = signal('');
  protected readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.total() / TAMANO_PAGINA)),
  );

  constructor() {
    this.cargar();
  }

  protected irA(pagina: number): void {
    this.pagina.set(pagina);
    this.cargar();
  }

  protected constancia(r: Resultado): void {
    this.error.set('');
    this.api.constancia(r.id).subscribe({
      next: (b) => guardarArchivo(b, `constancia_resultado_${r.id}.pdf`),
      error: () => this.error.set('No se pudo descargar la constancia.'),
    });
  }

  private cargar(): void {
    this.cargando.set(true);
    this.error.set('');
    this.api.listar(this.pagina()).subscribe({
      next: (r) => {
        this.resultados.set(r.results);
        this.total.set(r.count);
        this.cargando.set(false);
      },
      error: (err) => {
        this.error.set(mensajeError(err));
        this.cargando.set(false);
      },
    });
  }
}