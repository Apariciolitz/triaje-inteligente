// Captura «Cloud – Modelo híbrido»: entorno local, conectividad segura y nube.

import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/validadores.dart';
import '../estado/proveedor.dart';
import 'comunes.dart';

class PaginaNube extends StatelessWidget {
  const PaginaNube({super.key});

  Widget _bloque(String titulo, String sub, IconData icono, List<String> items, Color fondo, Color borde) => Container(
        width: 250,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: fondo, border: Border.all(color: borde), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icono, color: Colores.navy2), const SizedBox(width: 8), Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, color: Colores.navy)))]),
          Text(sub, style: const TextStyle(color: Colores.tenue, fontSize: 12)),
          const SizedBox(height: 6),
          for (final i in items) Text('• $i', style: const TextStyle(fontSize: 12.5)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    final azul = const Color(0xFFEAF4FB), azulB = const Color(0xFFB9D7EE);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Encabezado('Cloud – modelo híbrido', 'Entorno local + nube', sub: 'El triaje funciona en el hospital aunque falle internet; la nube recibe solo información autorizada y seudonimizada.'),
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _bloque('Punto de atención', 'Triaje en emergencia', Icons.person_pin, ['Registro de síntomas', 'Signos vitales', 'Motivo de consulta', 'Prioridad sugerida'], azul, azulB),
          _bloque('Aplicación de triaje (IA)', 'Inferencia local', Icons.memory, ['Modelo en el dispositivo', 'Clasificación de prioridad', 'Funciona con conectividad limitada'], azul, azulB),
          _bloque('Historia clínica digital', 'Red del hospital', Icons.storage, ['Antecedentes', 'Diagnósticos previos', 'Registros relevantes'], azul, azulB),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(s.enLinea ? Icons.sync_alt : Icons.sync_disabled, size: 36, color: s.enLinea ? Colores.teal : Colores.rojo),
            Text(s.enLinea ? 'Conectividad segura' : 'Sin conexión', style: TextStyle(fontWeight: FontWeight.w800, color: s.enLinea ? Colores.teal : Colores.rojo)),
            const Text('Datos cifrados · solo autorizados', style: TextStyle(fontSize: 11.5, color: Colores.tenue)),
          ]),
          _bloque('Nube: almacenamiento', 'Datos para análisis', Icons.cloud_upload_outlined, ['Solo datos seudonimizados', 'Respaldo institucional'], Colores.menta, Colores.mentaBorde),
          _bloque('Nube: análisis y modelos', 'Entrenamiento y monitoreo', Icons.insights, ['Reentrenamiento', 'PLN y métricas', 'Mejora continua del modelo'], Colores.menta, Colores.mentaBorde),
          _bloque('Nube: escalabilidad', 'Recursos bajo demanda', Icons.dns_outlined, ['Mayor capacidad en brotes de dengue'], Colores.menta, Colores.mentaBorde),
        ]),
        const SizedBox(height: 14),
        Tarjeta(
          titulo: 'Conectividad (simulación)',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: s.enLinea,
              onChanged: (v) {
                s.cambiarConexion(v);
                aviso(context, v ? 'Conexión restablecida: registros sincronizados.' : 'Sin conexión: el triaje sigue funcionando en el entorno local.');
              },
              title: Text(s.enLinea ? 'En línea con la nube' : 'Sin conexión con la nube'),
              subtitle: const Text('Desactive para demostrar la continuidad operativa: el registro, la historia clínica y la sugerencia siguen funcionando; los datos esperan en la cola.'),
            ),
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('Pendientes de envío: ${s.pendientesSync} · enviados: ${s.cola.length - s.pendientesSync}', style: const TextStyle(fontWeight: FontWeight.w700)),
              OutlinedButton.icon(onPressed: s.enLinea && s.pendientesSync > 0 ? () => s.sincronizar() : null, icon: const Icon(Icons.cloud_sync), label: const Text('Sincronizar ahora')),
            ]),
          ]),
        ),
        Tarjeta(
          titulo: 'Cola de sincronización (lo que sale del hospital)',
          child: s.cola.isEmpty
              ? const Text('Aún no hay registros. Cada registro, clasificación y desenlace genera un envío seudonimizado.', style: TextStyle(color: Colores.tenue))
              : Tabla(['#', 'Tipo', 'Creado', 'Estado', 'Contenido enviado'], [
                  for (final e in s.cola.reversed.take(60))
                    [
                      Text('${e.id}'),
                      Text(e.tipo),
                      Text(hhmm(e.creado)),
                      e.enviado == null ? const Text('Pendiente', style: TextStyle(color: Colores.ambar, fontWeight: FontWeight.w700)) : Text('Enviado ${hhmm(e.enviado!)}', style: const TextStyle(color: Colores.verde)),
                      Text(const JsonEncoder().convert(e.carga), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                    ],
                ]),
        ),
        const Tarjeta(
          titulo: 'Seguridad transversal (en ambos entornos)',
          child: Wrap(spacing: 24, runSpacing: 8, children: [
            Text('🔒 Cifrado en tránsito y en reposo'),
            Text('👥 Control de acceso por roles'),
            Text('📄 Trazabilidad y auditoría encadenada'),
            Text('🛡 Ley N.º 29733 y su reglamento (D.S. 016-2024-JUS)'),
          ]),
        ),
        const FranjaClave('Intercambio seguro y autorizado · Controles institucionales de protección de datos'),
      ]),
    );
  }
}
