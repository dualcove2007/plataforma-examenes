import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';
import { Pagina } from '../../core/models/pagina';

export interface Banco {
  id: number;
  materia: number;
  materia_nombre: string;
  docente: number;
  docente_nombre: string;
  titulo: string;
  descripcion: string;
  activo: boolean;
  fecha_creacion: string;
  total_preguntas: number;
}

export interface FiltrosBancos {
  page: number;
  search?: string;
  materia?: number;
  activo?: boolean;
}

export interface BancoEscritura {
  materia: number;
  titulo: string;
  descripcion: string;
  activo: boolean;
}

@Injectable({ providedIn: 'root' })
export class BancosService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/bancos/`;

  listar(f: FiltrosBancos): Observable<Pagina<Banco>> {
    let params = new HttpParams().set('page', f.page);
    if (f.search) params = params.set('search', f.search);
    if (f.materia !== undefined) params = params.set('materia', f.materia);
    if (f.activo !== undefined) params = params.set('activo', f.activo);
    return this.http.get<Pagina<Banco>>(this.url, { params });
  }

  obtener(id: number): Observable<Banco> {
    return this.http.get<Banco>(`${this.url}${id}/`);
  }

  crear(datos: BancoEscritura): Observable<Partial<Banco>> {
    return this.http.post<Partial<Banco>>(this.url, datos);
  }

  actualizar(id: number, datos: BancoEscritura): Observable<Partial<Banco>> {
    return this.http.patch<Partial<Banco>>(`${this.url}${id}/`, datos);
  }

  /** El backend no borra: marca el banco como inactivo. */
  desactivar(id: number): Observable<void> {
    return this.http.delete<void>(`${this.url}${id}/`);
  }
}