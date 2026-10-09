import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { EMPTY, Observable, expand, reduce } from 'rxjs';

import { environment } from '../../../environments/environment';
import { Pagina } from '../../core/models/pagina';

export interface Materia {
  id: number;
  nombre: string;
  descripcion: string;
}

export type MateriaEscritura = Pick<Materia, 'nombre' | 'descripcion'>;

@Injectable({ providedIn: 'root' })
export class MateriasService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/materias/`;

  listar(page: number, search?: string): Observable<Pagina<Materia>> {
    let params = new HttpParams().set('page', page);
    if (search) params = params.set('search', search);
    return this.http.get<Pagina<Materia>>(this.url, { params });
  }

  /** Todas las materias (recorre las páginas). Pensado para selectores. */
  listarTodas(): Observable<Materia[]> {
    const pedir = (page: number) => this.listar(page);
    return pedir(1).pipe(
      expand((r, i) => (r.next ? pedir(i + 2) : EMPTY)),
      reduce((acc, r) => acc.concat(r.results), [] as Materia[]),
    );
  }

  obtener(id: number): Observable<Materia> {
    return this.http.get<Materia>(`${this.url}${id}/`);
  }

  crear(datos: MateriaEscritura): Observable<Materia> {
    return this.http.post<Materia>(this.url, datos);
  }

  actualizar(id: number, datos: MateriaEscritura): Observable<Materia> {
    return this.http.patch<Materia>(`${this.url}${id}/`, datos);
  }

  /** Borra de verdad; el backend responde 409 si la materia tiene bancos. */
  eliminar(id: number): Observable<void> {
    return this.http.delete<void>(`${this.url}${id}/`);
  }
}