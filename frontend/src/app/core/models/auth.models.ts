export const Rol = {
  Administrador: 'Administrador',
  Docente: 'Docente',
  Estudiante: 'Estudiante',
} as const;

export type NombreRol = (typeof Rol)[keyof typeof Rol];

export interface Usuario {
  id: number;
  nombre: string;
  email: string;
  rol: NombreRol;
  permisos: string[];
  activo: boolean;
  fecha_creacion: string;
}

export interface Tokens {
  access: string;
  refresh: string;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse extends Tokens {
  usuario: Usuario;
}
