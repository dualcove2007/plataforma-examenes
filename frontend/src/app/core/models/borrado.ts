/** Respuesta del backend al eliminar bancos y preguntas. */
export interface ResultadoBorrado {
  accion: 'eliminado' | 'desactivado';
  mensaje: string;
}