import 'package:flutter/material.dart';
import '../core/datos.dart';
import '../core/validadores.dart';
import '../estado/app_state.dart';
import '../estado/entidades.dart';
import '../estado/proveedor.dart';
import 'comunes.dart';

class PaginaRegistro extends StatelessWidget {
  const PaginaRegistro({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    final reales = s.pacientes.where((p) => p.decision != null && !p.sintetico).toList();
    final alterado = s.verificarCadena();
    final puede = s.rol != Rol.comite;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Encabezado('Registro y auditoría', 'Trazabilidad de cada decisión', sub: 'Seguridad transversal: trazabilidad y registros de auditoría.'),
        Tarjeta(
          titulo: 'Registro de discrepancias y desenlaces',
          child: reales.isEmpty
              ? const Text('Aún no hay decisiones registradas.', style: TextStyle(color: Colores.tenue))
              : Tabla(['Código', 'Seudónimo', 'Hora', 'Modo', 'Sugerida', 'Decidida', 'Motivo del cambio', 'Desenlace 24 h'], [
                  for (final p in reales)
                    [
                      Text(p.id),
                      Text(p.seudo, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      Text(hhmm(p.decision!.ts)),
                      Text(p.decision!.modo == 'sombra' ? 'Sombra' : 'Piloto'),
                      p.decision!.sugeridaVisible == null ? const Text('oculta', style: TextStyle(color: Colores.tenue)) : InsigniaPrioridad(p.decision!.sugeridaVisible),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        InsigniaPrioridad(p.decision!.priorInicial),
                        if (p.decision!.prior != p.decision!.priorInicial) ...[const Text(' → '), InsigniaPrioridad(p.decision!.prior)],
                      ]),
                      Text(p.decision!.motivoTxt != null ? '${p.decision!.motivoCat}: ${p.decision!.motivoTxt}' : (p.decision!.sugeridaVisible == null ? '—' : 'coincide')),
                      p.desenlace != null
                          ? Text('${p.desenlace!.tipo}${p.desenlace!.critico ? ' (crítico)' : ''}', style: TextStyle(color: p.desenlace!.critico ? Colores.rojo : null, fontWeight: p.desenlace!.critico ? FontWeight.w700 : null))
                          : (puede ? TextButton(onPressed: () => _desenlace(context, s, p), child: const Text('Registrar')) : const Text('—')),
                    ],
                ]),
        ),
        Tarjeta(
          titulo: 'Registro de auditoría · cadena SHA-256',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            alterado == null
                ? Aviso.texto(TipoAviso.ok, '✓ Integridad verificada: ${s.auditoria.length} eventos encadenados sin alteraciones.')
                : Aviso.texto(TipoAviso.error, '✗ La cadena está alterada a partir del evento $alterado.'),
            const Text('Cada evento guarda el hash del anterior: si alguien modifica un evento, la verificación falla. No se registran nombres ni documentos, solo el código seudónimo (HMAC con clave institucional).', style: TextStyle(color: Colores.tenue, fontSize: 12.5)),
            const SizedBox(height: 8),
            Tabla(['#', 'Hora', 'Usuario', 'Acción', 'Paciente', 'Detalle', 'Hash'], [
              for (final e in s.auditoria.reversed.take(200))
                [
                  Text('${e.n}'),
                  Text(hhmm(e.ts)),
                  Text(e.usuario),
                  Text(e.accion),
                  Text('${e.codigo}\n${e.ref}', style: const TextStyle(fontSize: 12)),
                  Text(e.detalle, style: const TextStyle(fontSize: 12.5)),
                  Text('${e.hash.substring(0, 16)}…', style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5)),
                ],
            ]),
          ]),
        ),
      ]),
    );
  }

  Future<void> _desenlace(BuildContext context, AppState s, Paciente p) async {
    String? tipo;
    final hora = TextEditingController(text: hhmm(s.ahora));
    String? eTipo, eHora;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('Desenlace de ${p.id}'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Clasificado a las ${hhmm(p.decision!.ts)}. Crítico = UCI, cirugía de emergencia o fallecimiento dentro de 24 h.', style: const TextStyle(color: Colores.tenue)),
              const SizedBox(height: 10),
              Lista<String>('Desenlace', requerido: true, valor: tipo, opciones: kDesenlaces, texto: (x) => x, error: eTipo, alCambiar: (v) => set(() {
                    tipo = v;
                    eTipo = null;
                  })),
              Campo(hora, 'Hora del desenlace (HH:MM)', requerido: true, error: eHora, formatos: [Formatos.hora, Formatos.largo(5)], ayuda: 'Posterior a la clasificación y no futura.'),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final h = validarHora(hora.text, s.ahora, noAntesDe: p.decision!.ts, etiqueta: 'la hora del desenlace');
                set(() {
                  eTipo = tipo == null ? 'Seleccione el desenlace.' : null;
                  eHora = h.ok ? null : h.mensaje;
                });
                if (tipo != null && h.ok) Navigator.pop(ctx, true);
              },
              child: const Text('Guardar desenlace'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && tipo != null) {
      s.registrarDesenlace(p, tipo!, validarHora(hora.text, s.ahora).valor!);
      if (context.mounted) aviso(context, 'Desenlace registrado.');
    }
  }
}
