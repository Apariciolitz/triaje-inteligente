// Reglas de validación de todos los campos. Cada función devuelve un
// Resultado: ok + valor normalizado, o el mensaje de error que verá el usuario.

import 'datos.dart';

class Resultado<T> {
  final bool ok;
  final T? valor;
  final String? mensaje;
  final bool critico;
  final bool alerta;
  final int? edad;
  const Resultado.ok(this.valor, {this.critico = false, this.alerta = false, this.edad})
      : ok = true,
        mensaje = null;
  const Resultado.error(this.mensaje)
      : ok = false,
        valor = null,
        critico = false,
        alerta = false,
        edad = null;
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

final RegExp _soloDigitos = RegExp(r'^\d+$');
final RegExp _todosIguales = RegExp(r'^(.)\1+$');
final RegExp _signosCodigo = RegExp(r'[<>{}\\]');
const String _letras = 'A-Za-zÁÉÍÓÚÜÑáéíóúüñ';
final RegExp _letra = RegExp('[$_letras]');
final RegExp _nombre = RegExp("^[$_letras]+(?:[ '\\-][$_letras]+)*\$");
final RegExp _tripleLetra = RegExp('([$_letras])\\1\\1', caseSensitive: false);

bool esSecuencia(String s) => '0123456789012345'.contains(s) || '9876543210987654'.contains(s);
bool todosIguales(String s) => _todosIguales.hasMatch(s);
int _contarLetras(String s) => _letra.allMatches(s).length;

/* ---------------- DNI peruano ----------------
   Dígito verificador: módulo 11 con pesos 3-2-7-6-5-4-3-2.
   En el documento figura como número o como letra. */
const List<int> _pesos = [3, 2, 7, 6, 5, 4, 3, 2];
const List<String> _dvNum = ['6', '7', '8', '9', '0', '1', '1', '2', '3', '4', '5'];
const List<String> _dvLet = ['K', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];

({String numero, String letra}) digitoVerificador(String dni) {
  var s = 0;
  for (var i = 0; i < 8; i++) {
    s += int.parse(dni[i]) * _pesos[i];
  }
  var k = 11 - (s % 11);
  if (k == 11) k = 0;
  return (numero: _dvNum[k], letra: _dvLet[k]);
}

Resultado<String> validarDNI(String? dniRaw, String? dvRaw) {
  final dni = dniRaw ?? '';
  final dv = (dvRaw ?? '').trim().toUpperCase();
  if (dni.trim().isEmpty) return const Resultado.error('Ingrese el número de DNI.');
  if (dni.contains(RegExp(r'\s'))) return const Resultado.error('El DNI no debe contener espacios.');
  if (!_soloDigitos.hasMatch(dni)) return const Resultado.error('El DNI solo admite números del 0 al 9; no se permiten letras, guiones ni signos.');
  if (dni.length != 8) return Resultado.error('El DNI debe tener exactamente 8 dígitos (ingresó ${dni.length}).');
  if (todosIguales(dni)) return const Resultado.error('DNI no válido: no puede tener los 8 dígitos iguales (por ejemplo, 00000000 o 11111111).');
  if (esSecuencia(dni)) return const Resultado.error('DNI no válido: es una secuencia correlativa (por ejemplo, 12345678 o 87654321).');
  if (dv.isEmpty) return const Resultado.error('Ingrese el dígito verificador: es el carácter que aparece después del guion, junto al número de DNI.');
  if (!RegExp(r'^[0-9A-K]$').hasMatch(dv)) return const Resultado.error('El dígito verificador es un solo carácter: un número (0-9) o una letra de la A a la K.');
  final c = digitoVerificador(dni);
  if (dv != c.numero && dv != c.letra) {
    return const Resultado.error('El dígito verificador no corresponde a este número de DNI. Revise el documento físico: el número o el dígito están mal digitados.');
  }
  return Resultado.ok(dni);
}

Resultado<String> _validarDocExtranjero(String? raw, int min, int max, String nombre) {
  final v = (raw ?? '').trim().toUpperCase();
  if (v.isEmpty) return Resultado.error('Ingrese el número de $nombre.');
  if (!RegExp(r'^[A-Z0-9]+$').hasMatch(v)) return Resultado.error('${_cap(nombre)}: solo letras y números, sin espacios ni signos.');
  if (v.length < min || v.length > max) return Resultado.error('${_cap(nombre)}: debe tener entre $min y $max caracteres (ingresó ${v.length}).');
  if (!RegExp(r'\d').hasMatch(v)) return Resultado.error('${_cap(nombre)}: debe contener al menos un número.');
  if (todosIguales(v)) return const Resultado.error('Número no válido: todos los caracteres son iguales.');
  if (_soloDigitos.hasMatch(v) && esSecuencia(v)) return const Resultado.error('Número no válido: es una secuencia correlativa.');
  return Resultado.ok(v);
}

Resultado<String> validarCE(String? raw) => _validarDocExtranjero(raw, 8, 12, 'carné de extranjería');
Resultado<String> validarPasaporte(String? raw) => _validarDocExtranjero(raw, 6, 12, 'pasaporte');

Resultado<String> validarNombre(String? raw, String etiqueta) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return Resultado.error('Ingrese $etiqueta.');
  if (RegExp(r'\d').hasMatch(t)) return Resultado.error('${_cap(etiqueta)} no puede contener números.');
  if (t.contains('  ')) return Resultado.error('${_cap(etiqueta)} no puede tener espacios dobles.');
  if (!_nombre.hasMatch(t)) return Resultado.error('${_cap(etiqueta)} solo admite letras (con tildes y ñ), un espacio entre palabras, apóstrofo o guion.');
  if (t.replaceAll(RegExp(r"[ '\-]"), '').length < 2) return Resultado.error('${_cap(etiqueta)} debe tener al menos 2 letras.');
  if (t.length > 40) return Resultado.error('${_cap(etiqueta)} admite como máximo 40 caracteres (tiene ${t.length}).');
  if (_tripleLetra.hasMatch(t)) return Resultado.error('${_cap(etiqueta)} no puede repetir la misma letra tres veces seguidas.');
  return Resultado.ok(t);
}

Resultado<String> validarCelular(String? raw, {bool obligatorio = true}) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return obligatorio ? const Resultado.error('Ingrese el número de celular de contacto.') : const Resultado.ok('');
  if (!_soloDigitos.hasMatch(v)) return const Resultado.error('El celular solo admite números, sin espacios ni signos.');
  if (v.length != 9) return Resultado.error('El celular debe tener 9 dígitos (ingresó ${v.length}).');
  if (v[0] != '9') return const Resultado.error('El celular en Perú debe empezar con 9.');
  if (todosIguales(v.substring(1))) return const Resultado.error('Número de celular no válido: dígitos repetidos.');
  return Resultado.ok(v);
}

/// Fecha en formato DD/MM/AAAA.
Resultado<DateTime> validarFechaNac(String? raw, DateTime ahora) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return const Resultado.error('Ingrese la fecha de nacimiento.');
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(v);
  if (m == null) return const Resultado.error('La fecha de nacimiento debe tener el formato DD/MM/AAAA.');
  final d = int.parse(m.group(1)!), mes = int.parse(m.group(2)!), y = int.parse(m.group(3)!);
  final f = DateTime(y, mes, d);
  if (f.year != y || f.month != mes || f.day != d) return const Resultado.error('La fecha de nacimiento no existe en el calendario.');
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  if (f.isAfter(hoy)) return const Resultado.error('La fecha de nacimiento no puede ser posterior a hoy.');
  final e = edadEn(f, ahora);
  if (e > 120) return Resultado.error('La fecha de nacimiento da una edad de $e años; el máximo aceptado es 120.');
  return Resultado.ok(f, edad: e);
}

Resultado<int> validarEnteroRango(String? raw, int min, int max, String etiqueta) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return Resultado.error('Ingrese $etiqueta.');
  if (!RegExp(r'^-?\d+$').hasMatch(v)) return Resultado.error('${_cap(etiqueta)} debe ser un número entero, sin decimales ni letras.');
  final n = int.parse(v);
  if (n < min || n > max) return Resultado.error('${_cap(etiqueta)} debe estar entre $min y $max.');
  return Resultado.ok(n);
}

/// Texto libre genérico: motivos de cambio, señas, anulaciones, justificaciones.
Resultado<String> validarTexto(String? raw, int min, int max, String etiqueta) {
  final t = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return Resultado.error('Ingrese $etiqueta.');
  if (_signosCodigo.hasMatch(t)) return Resultado.error('${_cap(etiqueta)} no admite los signos < > { } ni barras invertidas.');
  if (t.length < min) return Resultado.error('${_cap(etiqueta)} debe tener al menos $min caracteres (tiene ${t.length}).');
  if (t.length > max) return Resultado.error('${_cap(etiqueta)} admite como máximo $max caracteres (tiene ${t.length}).');
  final sinEsp = t.replaceAll(' ', '');
  final letras = _contarLetras(t);
  if (letras < (min < 8 ? min : 8) || letras / sinEsp.length < 0.6) return Resultado.error('${_cap(etiqueta)} debe estar redactado con palabras, no solo con números o signos.');
  if (RegExp(r'(.)\1{4,}').hasMatch(t)) return Resultado.error('${_cap(etiqueta)} no puede repetir el mismo carácter cinco o más veces seguidas.');
  final palabras = t.split(' ').where((w) => RegExp('[$_letras]{2,}').hasMatch(w)).length;
  if (palabras < 2) return Resultado.error('${_cap(etiqueta)} debe tener al menos dos palabras.');
  return Resultado.ok(t);
}

/// Hora HH:MM; no futura y como máximo 12 h antes. Devuelve la fecha completa.
Resultado<DateTime> validarHora(String? raw, DateTime ahora, {DateTime? noAntesDe, String etiqueta = 'la hora de llegada'}) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return Resultado.error('Ingrese $etiqueta.');
  final m = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(v);
  if (m == null) return Resultado.error('${_cap(etiqueta)} debe tener el formato HH:MM (00:00 a 23:59).');
  var t = DateTime(ahora.year, ahora.month, ahora.day, int.parse(m.group(1)!), int.parse(m.group(2)!));
  if (t.isAfter(ahora)) t = t.subtract(const Duration(days: 1)); // fue ayer
  if (ahora.difference(t).inMinutes > 720) return Resultado.error('${_cap(etiqueta)} no puede ser de hace más de 12 horas ni posterior a la hora actual.');
  if (noAntesDe != null && t.isBefore(noAntesDe.subtract(const Duration(seconds: 59)))) {
    return Resultado.error('${_cap(etiqueta)} no puede ser anterior a ${hhmm(noAntesDe)}.');
  }
  return Resultado.ok(t);
}

String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/* ---------------- Signos vitales ---------------- */
Resultado<double> validarVital(VitalDef d, String? raw) {
  final v = (raw ?? '').trim().replaceAll(',', '.');
  if (v.isEmpty) return Resultado.error('Ingrese ${d.nombre.toLowerCase()} o marque «No medido» con el motivo.');
  if (RegExp(r'[eE+]').hasMatch(v)) return Resultado.error('${d.nombre}: no se admite notación científica ni signos.');
  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(v)) return Resultado.error('${d.nombre}: ingrese solo números${d.decimales > 0 ? ' (use punto o coma para el decimal)' : ''}.');
  if (d.decimales == 0 && v.contains('.')) return Resultado.error('${d.nombre} se registra en números enteros, sin decimales.');
  if (d.decimales == 1 && RegExp(r'\.\d{2,}$').hasMatch(v)) return Resultado.error('${d.nombre} admite como máximo un decimal.');
  final n = double.parse(v);
  if (n < d.min || n > d.max) {
    return Resultado.error('${d.nombre}: ${fmtNum(n)} ${d.unidad} es fisiológicamente imposible o un error de digitación. Rango aceptado: ${fmtNum(d.min)} a ${fmtNum(d.max)} ${d.unidad}.');
  }
  return Resultado.ok(n, critico: d.critico(n), alerta: d.alerta(n));
}

String fmtNum(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1).replaceAll('.', ',');

/// Reglas cruzadas entre signos vitales. Devuelve id del campo → mensaje.
Map<String, String> validarVitalesCruzado(Map<String, double?> vit) {
  final e = <String, String>{};
  final pas = vit['pas'], pad = vit['pad'];
  if (pas != null && pad != null) {
    if (pad >= pas) {
      e['pad'] = 'La presión diastólica debe ser menor que la sistólica.';
    } else if (pas - pad < 10) {
      e['pad'] = 'La diferencia entre sistólica y diastólica es menor de 10 mmHg: revise ambos valores.';
    }
  }
  if (pas == null && pad != null) e['pas'] = 'Si registra la diastólica también debe registrar la sistólica.';
  if (pad == null && pas != null) e['pad'] = 'Si registra la sistólica también debe registrar la diastólica.';
  return e;
}

/* ---------------- Motivo de consulta ---------------- */
Resultado<String> validarMotivo(String? raw) {
  final t = (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.isEmpty) return const Resultado.error('Describa el motivo de consulta con las palabras del paciente o del acompañante.');
  if (_signosCodigo.hasMatch(t)) return const Resultado.error('El motivo de consulta no admite los signos < > { } ni barras invertidas (posible código).');
  if (t.length < 10) return Resultado.error('El motivo de consulta debe tener al menos 10 caracteres (tiene ${t.length}).');
  if (t.length > 500) return Resultado.error('El motivo de consulta admite como máximo 500 caracteres (tiene ${t.length}).');
  final sinEsp = t.replaceAll(' ', '');
  if (_contarLetras(t) / sinEsp.length < 0.6) return const Resultado.error('El motivo de consulta debe redactarse con palabras; no puede ser mayormente números o signos.');
  if (RegExp(r'(.)\1{4,}', caseSensitive: false).hasMatch(t)) return const Resultado.error('El motivo de consulta no puede repetir el mismo carácter cinco o más veces seguidas.');
  final palabras = t.split(' ').where((w) => RegExp('[$_letras]{2,}').hasMatch(w)).toList();
  if (palabras.length < 2) return const Resultado.error('El motivo de consulta debe tener al menos dos palabras.');
  if (palabras.length >= 3 && palabras.map(normalizar).toSet().length == 1) return const Resultado.error('El motivo de consulta no puede ser la misma palabra repetida.');
  return Resultado.ok(t);
}

/// Minúsculas, sin tildes, sin signos (normalización para PLN).
String normalizar(String s) {
  const de = 'áéíóúüàèìòù';
  const a = 'aeiouuaeiou';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = de.indexOf(ch);
    b.write(i >= 0 ? a[i] : ch);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9ñ\s]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Filtro de seudonimización del texto libre antes de enviarlo a la nube.
String filtrarTexto(String txt, List<String> nombres) {
  var s = txt;
  s = s.replaceAll(RegExp(r'\b9\d{8}\b'), '[TEL]');
  s = s.replaceAll(RegExp(r'\b\d{8}\b'), '[DOC]');
  s = s.replaceAll(RegExp(r'\b[A-Z]{0,2}\d{6,12}\b'), '[DOC]');
  for (final n in nombres) {
    if (n.length < 3) continue;
    s = s.replaceAll(RegExp('(?<![$_letras])${RegExp.escape(n)}(?![$_letras])', caseSensitive: false), '[NOMBRE]');
  }
  return s;
}

/* ---------------- Acceso ---------------- */
Resultado<Usuario> validarLogin(String? u, String? c) {
  if ((u ?? '').trim().isEmpty) return const Resultado.error('Ingrese su usuario.');
  if ((c ?? '').isEmpty) return const Resultado.error('Ingrese su contraseña.');
  for (final x in kUsuarios) {
    if (x.usuario == u!.trim().toLowerCase() && x.clave == c) return Resultado.ok(x);
  }
  return const Resultado.error('Usuario o contraseña incorrectos.');
}
