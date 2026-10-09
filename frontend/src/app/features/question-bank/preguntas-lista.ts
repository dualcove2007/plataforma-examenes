import { Component, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { guardarArchivo } from '../../core/utils/descargar';
import { Pagina } from '../../core/models/pagina';
import { mensajeError } from '../../core/utils/api-error';
import { Banco, BancosService } from './bancos.service';
import {
  DIFICULTADES,
  Dificultad,
  ETIQUETA_DIFICULTAD,
  ETIQUETA_TIPO,
  Pregunta,
  PreguntasService,
  TIPOS,
  Tipo,
} from './preguntas.service';

const TAMANO_PAGINA = 10;

@Component({
  selector: 'app-preguntas-lista',
  imports: [RouterLink],
  template: `
    <p><a routerLink="/bancos">← Volver a bancos</a></p>

    <h2>Preguntas @if (banco(); as b) { <small>de «{{ b.titulo }}»</small> }</h2>

    <p><a [routerLink]="['/bancos', bancoId, 'preguntas', 'nueva']">Nueva pregunta</a></p>

    <p>
      <button type="button" (click)="plantilla()">Descargar plantilla</button>
      <button type="button" (click)="exportar()">Exportar a Excel</button>
      <input #archivo type="file" accept=".xlsx" />
      <button type="button" (click)="importar(archivo)">Importar</button>
    </p>

    <form (submit)="buscar($event, q.value, tipo.value, dificultad.value, estado.value)">
      <input #q type="search" placeholder="Buscar en el enunciado" />
      <select #tipo>
        <option value="">Todos los tipos</option>
        @for (t of tipos; track t.valor) {
          <option [value]="t.valor">{{ t.etiqueta }}</option>
        }
      </select>
      <select #dificultad>
        <option value="">Toda dificultad</option>
        @for (d of dificultades; track d.valor) {
          <option [value]="d.valor">{{ d.etiqueta }}</option>
        }
      </select>
      <select #estado>
        <option value="">Todas</option>
        <option value="true">Activas</option>
        <option value="false">Inactivas</option>
      </select>
      <button type="submit">Buscar</button>
    </form>

    @if (error()) {
      <p role="alert">{{ error() }}</p>
    }
    @if (aviso()) {
      <p role="status">{{ aviso() }}</p>
    }

    @if (cargando()) {
      <p>Cargando…</p>
    } @else if (preguntas().length === 0) {
      <p>No se encontraron preguntas.</p>
    } @else {
      <table>
        <thead>
          <tr>
            <th>Enunciado</th><th>Tipo</th><th>Dificultad</th><th>Puntaje</th>
            <th>Opciones</th><th>Estado</th><th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          @for (p of preguntas(); track p.id) {
            <tr>
              <td>{{ resumen(p.enunciado) }}</td>
              <td>{{ etiquetaTipo[p.tipo] }}</td>
              <td>{{ etiquetaDificultad[p.dificultad] }}</td>
              <td>{{ p.puntaje }}</td>
              <td>{{ p.opciones.length }}</td>
              <td>{{ p.activo ? 'Activa' : 'Inactiva' }}</td>
              <td>
                <a [routerLink]="['/bancos', bancoId, 'preguntas', p.id, 'editar']">Editar</a>
                <button type="button" (click)="eliminar(p)">Eliminar</button>
              </td>
            </tr>
          }
        </tbody>
      </table>

      <nav aria-label="Paginación">
        <button type="button" [disabled]="pagina() <= 1" (click)="irA(pagina() - 1)">Anterior</button>
        <span>Página {{ pagina() }} de {{ totalPaginas() }} ({{ total() }} preguntas)</span>
        <button type="button" [disabled]="pagina() >= totalPaginas()" (click)="irA(pagina() + 1)">Siguiente</button>
      </nav>
    }
  `,
})
export class PreguntasLista {
  private readonly route = inject(ActivatedRoute);
  private readonly servicio = inject(PreguntasService);
  private readonly bancosApi = inject(BancosService);

  protected readonly bancoId = Number(this.route.snapshot.paramMap.get('bancoId'));
  protected readonly tipos = TIPOS;
  protected readonly dificultades = DIFICULTADES;
  protected readonly etiquetaTipo = ETIQUETA_TIPO;
  protected readonly etiquetaDificultad = ETIQUETA_DIFICULTAD;

  protected readonly banco = signal<Banco | null>(null);
  protected readonly preguntas = signal<Pregunta[]>([]);
  protected readonly total = signal(0);
  protected readonly pagina = signal(1);
  protected readonly cargando = signal(false);
  protected readonly error = signal('');
  protected readonly aviso = signal('');
  protected readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.total() / TAMANO_PAGINA)),
  );

  private search = '';
  private tipo?: Tipo;
  private dificultad?: Dificultad;
  private activo?: boolean;

  constructor() {
    this.bancosApi.obtener(this.bancoId).subscribe({
      next: (b) => this.banco.set(b),
      error: (err) => this.error.set(mensajeError(err)),
    });
    this.cargar();
  }

  protected resumen(texto: string): string {
    return texto.length > 80 ? `${texto.slice(0, 80)}…` : texto;
  }

  protected buscar(
    evento: Event,
    texto: string,
    tipo: string,
    dificultad: string,
    estado: string,
  ): void {
    evento.preventDefault();
    this.search = texto.trim();
    this.tipo = tipo === '' ? undefined : (tipo as Tipo);
    this.dificultad = dificultad === '' ? undefined : (dificultad as Dificultad);
    this.activo = estado === '' ? undefined : estado === 'true';
    this.pagina.set(1);
    this.cargar();
  }

  protected irA(pagina: number): void {
    this.pagina.set(pagina);
    this.cargar();
  }

  protected eliminar(p: Pregunta): void {
    if (!confirm('¿Eliminar esta pregunta? Si ya se usó en algún examen, solo se desactivará.')) {
      return;
    }
    this.error.set('');
    this.aviso.set('');
    this.servicio.eliminar(p.id).subscribe({
      next: (r) => {
        this.aviso.set(r.mensaje);
        // Si era el único elemento de la última página, retrocede una página.
        if (r.accion === 'eliminado' && this.preguntas().length === 1 && this.pagina() > 1) {
          this.pagina.update((n) => n - 1);
        }
        this.cargar();
      },
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  protected plantilla(): void {
    this.servicio.plantilla().subscribe({
      next: (b) => guardarArchivo(b, 'plantilla_preguntas.xlsx'),
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  protected exportar(): void {
    this.servicio
      .exportar({
        banco: this.bancoId,
        search: this.search,
        tipo: this.tipo,
        dificultad: this.dificultad,
        activo: this.activo,
      })
      .subscribe({
        next: (b) => guardarArchivo(b, 'preguntas.xlsx'),
        error: (err) => this.error.set(mensajeError(err)),
      });
  }

  protected importar(input: HTMLInputElement): void {
    const archivo = input.files?.[0];
    if (!archivo) {
      this.error.set('Selecciona un archivo .xlsx.');
      return;
    }
    this.error.set('');
    this.aviso.set('');
    this.bancosApi.importar(this.bancoId, archivo).subscribe({
      next: (r) => {
        this.aviso.set(`Se importaron ${r.importadas} preguntas.`);
        input.value = '';
        this.pagina.set(1);
        this.cargar();
      },
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  private cargar(): void {
    this.cargando.set(true);
    this.error.set('');
    this.servicio
      .listar({
        page: this.pagina(),
        banco: this.bancoId,
        search: this.search,
        tipo: this.tipo,
        dificultad: this.dificultad,
        activo: this.activo,
      })
      .subscribe({
        next: (r: Pagina<Pregunta>) => {
          this.preguntas.set(r.results);
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