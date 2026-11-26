// Tema (colores del PPT) y componentes reutilizables.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/datos.dart';

class Colores {
  static const navy = Color(0xFF15284B); // títulos y cabecera del PPT
  static const navy2 = Color(0xFF1F3A66);
  static const teal = Color(0xFF1E7A80); // etiquetas «CLOUD – MODELO HÍBRIDO»
  static const menta = Color(0xFFE2F1ED); // recuadros verdes del PPT
  static const mentaBorde = Color(0xFFBFDFD6);
  static const fondo = Color(0xFFF4F7FB);
  static const linea = Color(0xFFD9E0EA);
  static const texto = Color(0xFF1B2533);
  static const tenue = Color(0xFF5B6778);
  static const rojo = Color(0xFFC62828);
  static const rojoS = Color(0xFFFDECEC);
  static const ambar = Color(0xFF9A5B00);
  static const ambarS = Color(0xFFFFF4E0);
  static const verde = Color(0xFF2E7D32);
  static const verdeS = Color(0xFFE7F4E8);
  static const azulS = Color(0xFFE8F0FB);
}

ThemeData temaApp() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colores.navy, primary: Colores.navy, secondary: Colores.teal, surface: Colors.white),
    scaffoldBackgroundColor: Colores.fondo,
  );
  return base.copyWith(
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      errorMaxLines: 4,
      helperMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: Colores.navy, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: Colores.navy, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
  );
}

String fmt(double? x, [int d = 2]) => x == null ? '—' : x.toStringAsFixed(d).replaceAll('.', ',');
String pct(double? x) => x == null ? '—' : '${(x * 100).round()} %';

/// Tarjeta con título en el estilo de las etiquetas del PPT.
class Tarjeta extends StatelessWidget {
  final String? titulo;
  final Widget child;
  final Widget? accion;
  final Color? color;
  const Tarjeta({super.key, this.titulo, required this.child, this.accion, this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color ?? Colors.white, border: Border.all(color: Colores.linea), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (titulo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Expanded(child: Text(titulo!.toUpperCase(), style: const TextStyle(fontSize: 12.5, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: Colores.teal))),
              if (accion != null) accion!,
            ]),
          ),
        child,
      ]),
    );
  }
}

enum TipoAviso { ok, alerta, info, error }

class Aviso extends StatelessWidget {
  final TipoAviso tipo;
  final Widget child;
  const Aviso(this.tipo, this.child, {super.key});
  factory Aviso.texto(TipoAviso t, String s, {Key? key}) => Aviso(t, Text(s), key: key);
  @override
  Widget build(BuildContext context) {
    final (fondo, borde, fg) = switch (tipo) {
      TipoAviso.ok => (Colores.verdeS, const Color(0xFFA5D6A7), const Color(0xFF1B5E20)),
      TipoAviso.alerta => (Colores.ambarS, const Color(0xFFF3C77B), Colores.ambar),
      TipoAviso.info => (Colores.menta, Colores.mentaBorde, Colores.teal),
      TipoAviso.error => (Colores.rojoS, Colores.rojo, const Color(0xFF8E1B1B)),
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: fondo, border: Border.all(color: borde), borderRadius: BorderRadius.circular(10)),
      child: DefaultTextStyle.merge(style: TextStyle(color: fg, fontSize: 13), child: child),
    );
  }
}

/// Resumen de errores al inicio de un formulario.
class ResumenErrores extends StatelessWidget {
  final Map<String, String> errores;
  const ResumenErrores(this.errores, {super.key});
  @override
  Widget build(BuildContext context) {
    if (errores.isEmpty) return const SizedBox.shrink();
    return Aviso(
      TipoAviso.error,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Corrija ${errores.length} campo(s) antes de continuar:', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        ...errores.values.map((m) => Text('• $m')),
      ]),
    );
  }
}

class KV extends StatelessWidget {
  final String k;
  final String v;
  final Color? color;
  const KV(this.k, this.v, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F5)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: Text(k, style: const TextStyle(color: Colores.tenue))),
        const SizedBox(width: 8),
        Expanded(flex: 3, child: Text(v, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, color: color))),
      ]),
    );
  }
}

class InsigniaPrioridad extends StatelessWidget {
  final int? nivel;
  const InsigniaPrioridad(this.nivel, {super.key});
  @override
  Widget build(BuildContext context) {
    final n = nivel;
    final c = n == null ? const Color(0xFF6B7788) : pr(n).color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(999)),
      child: Text(n == null ? 'Pendiente' : pr(n).romano, style: TextStyle(color: n == 3 ? const Color(0xFF3B2B00) : Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class CajaPrioridad extends StatelessWidget {
  final int nivel;
  final String titulo;
  final double ancho;
  const CajaPrioridad(this.nivel, {super.key, this.titulo = 'Prioridad', this.ancho = 150});
  @override
  Widget build(BuildContext context) {
    final p = pr(nivel);
    return Container(
      width: ancho,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(titulo, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(p.romano, style: TextStyle(color: Colors.white, fontSize: ancho > 200 ? 72 : 46, fontWeight: FontWeight.w900, height: 1.1)),
        Text(p.corto, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Campo de texto con etiqueta, error y formateadores.
class Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String etiqueta;
  final String? error;
  final String? ayuda;
  final bool requerido;
  final TextInputType? teclado;
  final List<TextInputFormatter>? formatos;
  final int? maxLength;
  final int lineas;
  final bool habilitado;
  final Widget? sufijo;
  final bool oculto;
  final ValueChanged<String>? alCambiar;
  final String? pista;
  final TextCapitalization mayus;
  const Campo(this.ctrl, this.etiqueta, {super.key, this.error, this.ayuda, this.requerido = false, this.teclado, this.formatos, this.maxLength, this.lineas = 1, this.habilitado = true, this.sufijo, this.oculto = false, this.alCambiar, this.pista, this.mayus = TextCapitalization.none});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        enabled: habilitado,
        obscureText: oculto,
        keyboardType: teclado,
        inputFormatters: formatos,
        maxLength: maxLength,
        minLines: lineas,
        maxLines: lineas == 1 ? 1 : lineas + 2,
        textCapitalization: mayus,
        onChanged: alCambiar,
        decoration: InputDecoration(
          labelText: requerido ? '$etiqueta *' : etiqueta,
          errorText: error,
          helperText: ayuda,
          hintText: pista,
          suffixIcon: sufijo,
          counterText: lineas > 1 ? null : '',
        ),
      ),
    );
  }
}

/// Lista desplegable con error.
class Lista<T> extends StatelessWidget {
  final String etiqueta;
  final T? valor;
  final List<T> opciones;
  final String Function(T) texto;
  final ValueChanged<T?>? alCambiar;
  final String? error;
  final bool requerido;
  final String? ayuda;
  const Lista(this.etiqueta, {super.key, required this.valor, required this.opciones, required this.texto, required this.alCambiar, this.error, this.requerido = false, this.ayuda});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<T>(
        key: ValueKey('$etiqueta-$valor-${opciones.length}'),
        value: valor,
        isExpanded: true,
        items: opciones.map((o) => DropdownMenuItem<T>(value: o, child: Text(texto(o), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: alCambiar,
        decoration: InputDecoration(labelText: requerido ? '$etiqueta *' : etiqueta, errorText: error, helperText: ayuda),
      ),
    );
  }
}

/// Formateadores de entrada: impiden escribir caracteres que no corresponden al campo.
class Formatos {
  static final digitos = FilteringTextInputFormatter.digitsOnly;
  static final decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));
  static final dv = FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Ka-k]'));
  static final alfanum = FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z]'));
  static final fecha = FilteringTextInputFormatter.allow(RegExp(r'[0-9/]'));
  static final hora = FilteringTextInputFormatter.allow(RegExp(r'[0-9:]'));
  static TextInputFormatter largo(int n) => LengthLimitingTextInputFormatter(n);
  static final mayusculas = TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase()));
}

void aviso(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colores.rojo : Colores.navy, behavior: SnackBarBehavior.floating));
}

/// Diálogo de confirmación; si [palabra] no es null, exige escribirla.
Future<bool> confirmar(BuildContext context, String titulo, String texto, {String? palabra, String boton = 'Confirmar'}) async {
  final ctrl = TextEditingController();
  String? err;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(texto),
            if (palabra != null) ...[
              const SizedBox(height: 12),
              TextField(controller: ctrl, decoration: InputDecoration(labelText: 'Escriba $palabra para confirmar', errorText: err)),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (palabra != null && ctrl.text.trim() != palabra) {
                set(() => err = 'Debe escribir exactamente $palabra.');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: Text(boton),
          ),
        ],
      ),
    ),
  );
  return r ?? false;
}

/// Diálogo que pide un texto validado (motivos, justificaciones).
Future<String?> pedirTexto(BuildContext context, String titulo, String etiqueta, String? Function(String) validar, {String? descripcion, String boton = 'Guardar'}) async {
  final ctrl = TextEditingController();
  String? err;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (descripcion != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(descripcion, style: const TextStyle(color: Colores.tenue))),
            TextField(controller: ctrl, minLines: 3, maxLines: 5, maxLength: 300, decoration: InputDecoration(labelText: '$etiqueta *', errorText: err)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final e = validar(ctrl.text);
              if (e != null) {
                set(() => err = e);
                return;
              }
              Navigator.pop(ctx, ctrl.text.trim().replaceAll(RegExp(r'\s+'), ' '));
            },
            child: Text(boton),
          ),
        ],
      ),
    ),
  );
}

class Encabezado extends StatelessWidget {
  final String etiqueta;
  final String titulo;
  final String? sub;
  final Widget? accion;
  const Encabezado(this.etiqueta, this.titulo, {super.key, this.sub, this.accion});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.end, spacing: 12, runSpacing: 8, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(etiqueta.toUpperCase(), style: const TextStyle(color: Colores.teal, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12.5)),
          const SizedBox(height: 2),
          Text(titulo, style: const TextStyle(color: Colores.navy, fontWeight: FontWeight.w800, fontSize: 24)),
          if (sub != null) Text(sub!, style: const TextStyle(color: Colores.tenue)),
        ]),
        if (accion != null) accion!,
      ]),
    );
  }
}

/// Franja verde inferior, como la frase-resumen de cada diapositiva.
class FranjaClave extends StatelessWidget {
  final String texto;
  const FranjaClave(this.texto, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(color: Colores.menta, border: Border.all(color: Colores.mentaBorde), borderRadius: BorderRadius.circular(12)),
      child: Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Colores.teal, fontWeight: FontWeight.w800, fontSize: 15)),
    );
  }
}

/// Tabla simple con desplazamiento horizontal.
class Tabla extends StatelessWidget {
  final List<String> columnas;
  final List<List<Widget>> filas;
  const Tabla(this.columnas, this.filas, {super.key});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 72,
        columnSpacing: 18,
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF46536A)),
        columns: columnas.map((c) => DataColumn(label: Text(c.toUpperCase()))).toList(),
        rows: filas.map((f) => DataRow(cells: f.map((w) => DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: w))).toList())).toList(),
      ),
    );
  }
}

Widget cumple(bool? ok, {String si = '✓ cumple', String no = '✗ no cumple'}) {
  if (ok == null) return const Text('sin datos', style: TextStyle(color: Colores.tenue));
  return Text(ok ? si : no, style: TextStyle(color: ok ? Colores.verde : Colores.rojo, fontWeight: FontWeight.w700));
}
