import { DatePipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';

import { Pagina } from '../../core/models/pagina';
import { mensajeError } from '../../core/utils/api-error';
import { Banco, BancosService } from '../question-bank/bancos.service';
import { ETIQUETA_TIPO, Pregunta, PreguntasService } from '../question-bank/preguntas.service';
import {
  Asignacion,
  ETIQUETA_ESTADO_EXAMEN,
  Estudiante,
  ExamenDetalle as DatosExamen,
  ExamenPregunta,
  ExamenesService,
} from './examenes.service';

const TAMANO_PAGINA = 10;

@Component({
  selector: 'app-examen-detalle',
  imports: [RouterLink, DatePipe],
  template: `
    <p><a routerLink="/examenes">← Volver a exámenes</a></p>

    @if (error()) {
      <p role="alert">{{ error() }}</p>
    }
    @if (aviso()) {
      <p role="status">{{ aviso() }}</p>
    }

    @if (examen(); as e) {
      <h2>{{ e.titulo }}</h2>
      <p>{{ e.materia_nombre }} · {{ etiquetaEstado[e.estado] }}</p>
      <p>
        Del {{ e.fecha_inicio | date: 'dd/MM/yyyy HH:mm' }} al
        {{ e.fecha_fin | date: 'dd/MM/yyyy HH:mm' }} · {{ e.duracion_minutos }} min ·
        {{ e.intentos_permitidos }} intento(s) · {{ e.preguntas.length }} preguntas ·
        {{ e.puntaje_total ?? 0 }} puntos
      </p>

      <h3>Preguntas del examen</h3>
      @if (e.preguntas.length === 0) {
        <p>Aún no hay preguntas.</p>
      } @else {
        <table>
          <thead>
            <tr><th>#</th><th>Enunciado</th><th>Tipo</th><th>Puntaje</th><th>Acciones</th></tr>
          </thead>
          <tbody>
            @for (p of e.preguntas; track p.id) {
              <tr>
                <td>{{ p.orden }}</td>
                <td>{{ resumen(p.enunciado) }}</td>
                <td>{{ etiquetaTipo[p.tipo] }}</td>
                <td>{{ p.puntaje }}</td>
                <td>
                  @if (esBorrador()) {
                    <button type="button" (click)="quitar(p)">Quitar</button>
                  }
                </td>
              </tr>
            }
          </tbody>
        </table>
      }

      @if (esBorrador()) {
        <h3>Agregar preguntas</h3>
        @if (bancos().length === 0) {
          <p>No tienes bancos activos de esta materia.</p>
        } @else {
          <label>
            Banco
            <select #banco (change)="elegirBanco(banco.value)">
              <option value="">Selecciona un banco</option>
              @for (b of bancos(); track b.id) {
                <option [value]="b.id">{{ b.titulo }}</option>
              }
            </select>
          </label>
        }

        @if (bancoId() !== null) {
          @if (preguntasBanco().length === 0) {
            <p>Este banco no tiene preguntas activas.</p>
          } @else {
            <table>
              <thead>
                <tr><th>Enunciado</th><th>Tipo</th><th>Puntaje</th><th></th></tr>
              </thead>
              <tbody>
                @for (p of preguntasBanco(); track p.id) {
                  <tr>
                    <td>{{ resumen(p.enunciado) }}</td>
                    <td>{{ etiquetaTipo[p.tipo] }}</td>
                    <td>{{ p.puntaje }}</td>
                    <td>
                      <button
                        type="button"
                        [disabled]="idsEnExamen().has(p.id)"
                        (click)="agregar(p)"
                      >
                        {{ idsEnExamen().has(p.id) ? 'Ya agregada' : 'Agregar' }}
                      </button>
                    </td>
                  </tr>
                }
              </tbody>
            </table>
            <nav aria-label="Paginación de preguntas">
              <button type="button" [disabled]="pagPreg() <= 1" (click)="irAPreguntas(pagPreg() - 1)">Anterior</button>
              <span>Página {{ pagPreg() }} de {{ totalPagPreg() }}</span>
              <button type="button" [disabled]="pagPreg() >= totalPagPreg()" (click)="irAPreguntas(pagPreg() + 1)">Siguiente</button>
            </nav>
          }
        }
      }

      <h3>Estudiantes asignados</h3>
      @if (asignaciones().length === 0) {
        <p>Aún no hay estudiantes asignados.</p>
      } @else {
        <table>
          <thead>
            <tr><th>Nombre</th><th>Correo</th><th>Estado</th><th>Asignado el</th></tr>
          </thead>
          <tbody>
            @for (a of asignaciones(); track a.id) {
              <tr>
                <td>{{ a.estudiante_nombre }}</td>
                <td>{{ a.estudiante_email }}</td>
                <td>{{ a.estado }}</td>
                <td>{{ a.fecha_asignacion | date: 'dd/MM/yyyy HH:mm' }}</td>
              </tr>
            }
          </tbody>
        </table>
      }

      @if (puedeAsignar()) {
        <h3>Asignar estudiantes</h3>
        <form (submit)="buscarEstudiantes($event, q.value)">
          <input #q type="search" placeholder="Buscar por nombre o correo" />
          <button type="submit">Buscar</button>
        </form>

        @if (estudiantes().length === 0) {
          <p>No se encontraron estudiantes.</p>
        } @else {
          <table>
            <thead>
              <tr><th>Nombre</th><th>Correo</th><th></th></tr>
            </thead>
            <tbody>
              @for (s of estudiantes(); track s.id) {
                <tr>
                  <td>{{ s.nombre }}</td>
                  <td>{{ s.email }}</td>
                  <td>
                    <button
                      type="button"
                      [disabled]="idsAsignados().has(s.id)"
                      (click)="asignar(s)"
                    >
                      {{ idsAsignados().has(s.id) ? 'Asignado' : 'Asignar' }}
                    </button>
                  </td>
                </tr>
              }
            </tbody>
          </table>
          <nav aria-label="Paginación de estudiantes">
            <button type="button" [disabled]="pagEst() <= 1" (click)="irAEstudiantes(pagEst() - 1)">Anterior</button>
            <span>Página {{ pagEst() }} de {{ totalPagEst() }}</span>
            <button type="button" [disabled]="pagEst() >= totalPagEst()" (click)="irAEstudiantes(pagEst() + 1)">Siguiente</button>
          </nav>
        }
      }
    } @else if (!error()) {
      <p>Cargando…</p>
    }
  `,
})
export class ExamenDetalle {
  private readonly route = inject(ActivatedRoute);
  private readonly api = inject(ExamenesService);
  private readonly bancosApi = inject(BancosService);
  private readonly preguntasApi = inject(PreguntasService);

  private readonly id = Number(this.route.snapshot.paramMap.get('id'));

  protected readonly etiquetaEstado = ETIQUETA_ESTADO_EXAMEN;
  protected readonly etiquetaTipo = ETIQUETA_TIPO;

  protected readonly examen = signal<DatosExamen | null>(null);
  protected readonly asignaciones = signal<Asignacion[]>([]);
  protected readonly error = signal('');
  protected readonly aviso = signal('');

  protected readonly bancos = signal<Banco[]>([]);
  protected readonly bancoId = signal<number | null>(null);
  protected readonly preguntasBanco = signal<Pregunta[]>([]);
  protected readonly pagPreg = signal(1);
  protected readonly totalPreg = signal(0);

  protected readonly estudiantes = signal<Estudiante[]>([]);
  protected readonly pagEst = signal(1);
  protected readonly totalEst = signal(0);
  private searchEst = '';

  protected readonly esBorrador = computed(() => this.examen()?.estado === 'borrador');
  protected readonly puedeAsignar = computed(() => {
    const estado = this.examen()?.estado;
    return estado === 'borrador' || estado === 'publicado';
  });
  protected readonly idsEnExamen = computed(
    () => new Set(this.examen()?.preguntas.map((p) => p.pregunta) ?? []),
  );
  protected readonly idsAsignados = computed(
    () => new Set(this.asignaciones().map((a) => a.estudiante)),
  );
  protected readonly totalPagPreg = computed(() =>
    Math.max(1, Math.ceil(this.totalPreg() / TAMANO_PAGINA)),
  );
  protected readonly totalPagEst = computed(() =>
    Math.max(1, Math.ceil(this.totalEst() / TAMANO_PAGINA)),
  );

  constructor() {
    this.cargarExamen(true);
    this.cargarAsignaciones();
    this.cargarEstudiantes();
  }

  protected resumen(texto: string): string {
    return texto.length > 80 ? `${texto.slice(0, 80)}…` : texto;
  }

  // ---------------- preguntas del examen ----------------
  protected elegirBanco(valor: string): void {
    this.bancoId.set(valor === '' ? null : Number(valor));
    this.pagPreg.set(1);
    this.preguntasBanco.set([]);
    if (this.bancoId() !== null) this.cargarPreguntasBanco();
  }

  protected irAPreguntas(pagina: number): void {
    this.pagPreg.set(pagina);
    this.cargarPreguntasBanco();
  }

  protected agregar(p: Pregunta): void {
    this.limpiar();
    this.api.agregarPregunta(this.id, p.id).subscribe({
      next: () => {
        this.aviso.set('Pregunta agregada.');
        this.cargarExamen(false);
      },
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  protected quitar(item: ExamenPregunta): void {
    if (!confirm('¿Quitar esta pregunta del examen?')) return;
    this.limpiar();
    this.api.quitarPregunta(this.id, item.pregunta).subscribe({
      next: () => {
        this.aviso.set('Pregunta quitada.');
        this.cargarExamen(false);
      },
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  // ---------------- asignaciones ----------------
  protected buscarEstudiantes(evento: Event, texto: string): void {
    evento.preventDefault();
    this.searchEst = texto.trim();
    this.pagEst.set(1);
    this.cargarEstudiantes();
  }

  protected irAEstudiantes(pagina: number): void {
    this.pagEst.set(pagina);
    this.cargarEstudiantes();
  }

  protected asignar(s: Estudiante): void {
    this.limpiar();
    this.api.asignar(this.id, [s.id]).subscribe({
      next: () => {
        this.aviso.set(`«${s.nombre}» fue asignado al examen.`);
        this.cargarAsignaciones();
      },
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  // ---------------- cargas ----------------
  private limpiar(): void {
    this.error.set('');
    this.aviso.set('');
  }

  private cargarExamen(inicial: boolean): void {
    this.api.obtenerDetalle(this.id).subscribe({
      next: (e) => {
        this.examen.set(e);
        if (inicial) this.cargarBancos(e.materia);
      },
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  private cargarAsignaciones(): void {
    this.api.asignaciones(this.id).subscribe({
      next: (a) => this.asignaciones.set(a),
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  private cargarBancos(materia: number): void {
    this.bancosApi.listar({ page: 1, materia, activo: true }).subscribe({
      next: (r: Pagina<Banco>) => this.bancos.set(r.results),
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  private cargarPreguntasBanco(): void {
    const banco = this.bancoId();
    if (banco === null) return;
    this.preguntasApi.listar({ page: this.pagPreg(), banco, activo: true }).subscribe({
      next: (r: Pagina<Pregunta>) => {
        this.preguntasBanco.set(r.results);
        this.totalPreg.set(r.count);
      },
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  private cargarEstudiantes(): void {
    this.api.estudiantes(this.pagEst(), this.searchEst).subscribe({
      next: (r: Pagina<Estudiante>) => {
        this.estudiantes.set(r.results);
        this.totalEst.set(r.count);
      },
      error: (err) => this.error.set(mensajeError(err)),
    });
  }
}