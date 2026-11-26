import 'package:flutter/material.dart';
import '../core/algoritmos.dart';
import '../core/datos.dart';
import '../core/modelo.dart';
import '../core/validadores.dart';
import '../estado/proveedor.dart';
import 'comunes.dart';

const List<(String, String, String)> kReglas = [
  ('Acceso', 'Usuario y contraseña', 'Ambos obligatorios. Mensaje genérico si fallan (no revela cuál está mal). 3 intentos fallidos → bloqueo de 60 s. Cierre automático tras 15 min sin actividad. Cada rol ve solo sus secciones.'),
  ('Gobierno del modelo', 'Modo de operación', 'No se elige con un botón: depende del ciclo DevOps. Piloto asistido solo si hay una versión en Producción; si no, todo funciona en modo sombra.'),
  ('Gobierno del modelo', 'Ciclo de versión', 'Desarrollo → QA → Modo sombra → Aprobada → Producción. No se puede saltar pasos. Solo el comité cambia estados. Pasar a QA y a modo sombra exige autopruebas al 100 %.'),
  ('Gobierno del modelo', 'Aprobación', 'Exige al menos 20 decisiones evaluadas. Se contrastan recall I–II ≥ 0,90, precision ≥ 0,75, F1 ≥ 0,80, AUROC ≥ 0,85 y kappa ≥ 0,70. Si alguna no se cumple, justificación escrita de 30 a 300 caracteres.'),
  ('Registro', 'Tipo de documento', 'Obligatorio: DNI, carné de extranjería, pasaporte o sin documento (NN). No se niega la atención por falta de documento.'),
  ('Registro', 'Número de DNI', 'El teclado solo permite dígitos y un máximo de 8. Exactamente 8 dígitos. Rechaza dígitos iguales (00000000…) y secuencias (12345678, 87654321…).'),
  ('Registro', 'Dígito verificador', 'Obligatorio, 1 carácter (0-9 o A-K). Debe coincidir con el módulo 11 (pesos 3-2-7-6-5-4-3-2) sobre los 8 dígitos; se acepta el número o la letra.'),
  ('Registro', 'Verificación RENIEC (simulada)', 'Obligatorio pulsar «Verificar». No figura en el padrón → no se registra. Fallecido → bloqueo. Atención activa → bloqueo por duplicado. Si se edita el número tras verificar, se debe verificar otra vez.'),
  ('Registro', 'Confirmación de identidad', 'Casilla obligatoria: la persona coincide con el documento.'),
  ('Registro', 'Seguro', 'Viene del padrón. No asegurado: se atiende la emergencia igualmente y queda marcado.'),
  ('Registro', 'Carné de extranjería / pasaporte', 'CE 8-12 y pasaporte 6-12 letras o números, con al menos un número; no todos iguales ni secuencia. Pasaporte: nacionalidad obligatoria.'),
  ('Registro', 'Nombres y apellidos', 'Solo letras (tildes y ñ), espacio simple, apóstrofo o guion; 2 a 40 caracteres; sin números, sin espacios dobles, sin la misma letra 3 veces seguidas. Segundo apellido opcional.'),
  ('Registro', 'Fecha de nacimiento', 'DD/MM/AAAA, fecha real (rechaza 30/02), no futura, edad ≤ 120.'),
  ('Registro', 'Paciente NN', 'Sexo, edad aproximada (0-120) y señas (10-200 caracteres, con palabras) obligatorios. Código NN-AAAAMMDD-###.'),
  ('Registro', 'Llegada', 'Forma de llegada (lista) y hora HH:MM obligatorias; hora no futura y máximo 12 h antes.'),
  ('Registro', 'Acompañante', 'Obligatorio si el paciente es menor de 18. Nombre y apellido (2 palabras), parentesco y celular (9 dígitos, empieza con 9, no todos repetidos).'),
  ('Clínico', 'Motivo de consulta', '10-500 caracteres, 2 palabras como mínimo, 60 % letras; sin < > { } \\; sin un carácter repetido 5 veces ni la misma palabra repetida. Antes de ir a la nube, DNI, celular y nombre se reemplazan por [DOC], [TEL] y [NOMBRE].'),
  ('Clínico', 'Gestante', 'Obligatorio si es mujer de 10 a 55 años.'),
  ('Clínico', 'Signos vitales', 'Cada uno obligatorio o «No medido» con motivo (máximo 3). El teclado solo admite números. Enteros salvo temperatura (1 decimal, acepta coma).'),
  ('Clínico', 'Rangos imposibles (se rechazan)', 'PAS 40-300 · PAD 20-200 · FC 20-250 · FR 4-70 · T° 30-45 · SpO₂ 40-100 · Glasgow 3-15 · EVA 0-10.'),
  ('Clínico', 'Reglas cruzadas', 'PAD menor que PAS con diferencia ≥ 10 mmHg; si se registra una presión se registra la otra.'),
  ('Clínico', 'Valores críticos', 'SpO₂ < 85, PAS < 80 o ≥ 220, FC < 40 o > 150, FR < 8 o > 35, T° < 34 o ≥ 41, Glasgow ≤ 8, PAD ≥ 130: confirmar que se volvió a medir; fuerzan Prioridad I.'),
  ('Evaluación', 'Reglas de seguridad', 'Vital crítico → mínimo I. Signo de alarma en el texto (dolor torácico, convulsión, ACV, alarma de dengue, sangrado digestivo, intoxicación, autolesión, cefalea súbita, pérdida de conciencia) → mínimo II.'),
  ('Evaluación', 'Modelo', 'Probabilidad de desenlace crítico a 24 h → I ≥ 0,80 · II ≥ 0,35 · III ≥ 0,12 · IV. Se aplica la más urgente entre modelo y reglas. Se muestran los motivos.'),
  ('Decisión', 'Modificar prioridad', 'Distinta de la sugerida, motivo (lista) y detalle 15-300 caracteres. Si es menos urgente que la sugerida, confirmación obligatoria de reevaluación.'),
  ('Atención', 'Revaloración / tópico / anulación', 'Revalorar: prioridad distinta y motivo 15-300. Aviso «Revaluar ahora» al superar II 10 min, III 20 min, IV 60 min. Tópico: solo si hay uno libre; si hay más urgentes, confirmación. Anulación: solo antes de clasificar, motivo 15-200.'),
  ('Seguimiento', 'Desenlace y H4', 'Desenlace: lista cerrada, hora posterior a la clasificación y no futura, una sola vez. H4: Sí/No/No aplica obligatorio.'),
  ('Seguridad', 'Auditoría y datos', 'Eventos encadenados con SHA-256 (verificables). Solo seudónimos HMAC hacia la nube. Reinicio solo por el médico jefe escribiendo REINICIAR.'),
];

class _Prueba {
  final String nombre;
  final String esperado;
  final bool Function() f;
  const _Prueba(this.nombre, this.esperado, this.f);
}

List<_Prueba> _pruebas() {
  final ahora = DateTime.now();
  VitalDef v(String id) => vitalPorId(id);
  return [
    _Prueba('DNI 00000000 con dígito 6', 'Rechazado', () => !validarDNI('00000000', '6').ok),
    _Prueba('DNI 11111111', 'Rechazado', () => !validarDNI('11111111', 'A').ok),
    _Prueba('DNI 12345678 con su dígito', 'Rechazado', () => !validarDNI('12345678', '1').ok),
    _Prueba('DNI 87654321', 'Rechazado', () => !validarDNI('87654321', '5').ok),
    _Prueba('DNI de 7 dígitos', 'Rechazado', () => !validarDNI('4587231', '3').ok),
    _Prueba('DNI de 9 dígitos', 'Rechazado', () => !validarDNI('458723160', '3').ok),
    _Prueba('DNI con letra', 'Rechazado', () => !validarDNI('4587A316', '3').ok),
    _Prueba('DNI sin dígito verificador', 'Rechazado', () => !validarDNI('45872316', '').ok),
    _Prueba('DNI con dígito incorrecto', 'Rechazado', () => !validarDNI('45872316', '4').ok),
    _Prueba('DNI válido 45872316-3', 'Aceptado', () => validarDNI('45872316', '3').ok),
    _Prueba('DNI válido con letra 45872316-H', 'Aceptado', () => validarDNI('45872316', 'h').ok),
    _Prueba('DNI válido fuera del padrón (42388604-3)', 'Formato válido, no se registra', () => validarDNI('42388604', '3').ok && buscarPadron('42388604') == null),
    _Prueba('Nombre con número', 'Rechazado', () => !validarNombre('Juan2', 'el nombre').ok),
    _Prueba('Nombre <script>', 'Rechazado', () => !validarNombre('<script>', 'el nombre').ok),
    _Prueba('Nombre «Aaana»', 'Rechazado', () => !validarNombre('Aaana', 'el nombre').ok),
    _Prueba("Nombre «María José O'Neill»", 'Aceptado', () => validarNombre("María José O'Neill", 'el nombre').ok),
    _Prueba('Celular de 8 dígitos', 'Rechazado', () => !validarCelular('98765432').ok),
    _Prueba('Celular que no empieza con 9', 'Rechazado', () => !validarCelular('887654321').ok),
    _Prueba('Celular 999999999', 'Rechazado', () => !validarCelular('999999999').ok),
    _Prueba('Fecha 30/02/2001', 'Rechazado', () => !validarFechaNac('30/02/2001', ahora).ok),
    _Prueba('Fecha futura', 'Rechazado', () => !validarFechaNac('01/01/${ahora.year + 1}', ahora).ok),
    _Prueba('Edad de 130 años', 'Rechazado', () => !validarFechaNac('01/01/${ahora.year - 130}', ahora).ok),
    _Prueba('SpO₂ 101 %', 'Rechazado', () => !validarVital(v('spo2'), '101').ok),
    _Prueba('Temperatura 29,9 °C', 'Rechazado', () => !validarVital(v('temp'), '29,9').ok),
    _Prueba('Temperatura 36,9 (coma)', 'Aceptado = 36,9', () => validarVital(v('temp'), '36,9').valor == 36.9),
    _Prueba('Temperatura con 2 decimales', 'Rechazado', () => !validarVital(v('temp'), '36.95').ok),
    _Prueba('FC con decimal', 'Rechazado', () => !validarVital(v('fc'), '80.5').ok),
    _Prueba('FC «8o»', 'Rechazado', () => !validarVital(v('fc'), '8o').ok),
    _Prueba('FC 1e2', 'Rechazado', () => !validarVital(v('fc'), '1e2').ok),
    _Prueba('Glasgow 16', 'Rechazado', () => !validarVital(v('glasgow'), '16').ok),
    _Prueba('PAD mayor que PAS', 'Rechazado', () => validarVitalesCruzado({'pas': 90, 'pad': 95}).containsKey('pad')),
    _Prueba('Motivo «dolor»', 'Rechazado', () => !validarMotivo('dolor').ok),
    _Prueba('Motivo con <script>', 'Rechazado', () => !validarMotivo('<script>alert(1)</script> falta de aire').ok),
    _Prueba('Motivo solo números', 'Rechazado', () => !validarMotivo('1234567890 12345').ok),
    _Prueba('Motivo «aaaaaaaaaa bb»', 'Rechazado', () => !validarMotivo('aaaaaaaaaa bb').ok),
    _Prueba('Motivo misma palabra', 'Rechazado', () => !validarMotivo('dolor dolor dolor dolor').ok),
    _Prueba('SpO₂ 80 → Prioridad I por regla', 'Prioridad I', () => predecir(const EntradaModelo(edad: 40, vit: {'spo2': 80}, motivo: 'cansancio general')).prioridad == 1),
    _Prueba('Alarma de dengue → mínimo II', 'Prioridad ≤ II', () => predecir(const EntradaModelo(edad: 30, vit: {'temp': 38.6}, motivo: 'fiebre con petequias')).prioridad <= 2),
    _Prueba('Caso leve → Prioridad IV', 'Prioridad IV', () => predecir(const EntradaModelo(edad: 27, vit: {'pas': 118, 'pad': 76, 'fc': 80, 'fr': 16, 'temp': 37.1, 'spo2': 98, 'glasgow': 15, 'eva': 2}, motivo: 'Dolor de garganta y resfrío')).prioridad == 4),
    _Prueba('A* pone primero a Prioridad I', 'Correcto', () {
      const ps = [PacienteCola(3, 0), PacienteCola(1, 5), PacienteCola(2, 1)];
      return ps[aEstrella(ps, [0]).orden.first].prior == 1;
    }),
    _Prueba('A* costo ≤ orden de llegada', 'Correcto', () {
      const ps = [PacienteCola(3, 0), PacienteCola(2, 5), PacienteCola(4, 1), PacienteCola(1, 8)];
      return aEstrella(ps, [10, 12]).costo <= simularOrden(ps, [0, 2, 1, 3], [10, 12]).costo;
    }),
    _Prueba('Kappa con acuerdo perfecto', '1,00', () => kappa(const [Par(1, 1), Par(3, 3)]) == 1),
    _Prueba('SHA-256("abc") estándar', 'Coincide', () => sha256Hex('abc') == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'),
    _Prueba('Filtro de texto libre', 'Coincide', () => filtrarTexto('Rosa trae DNI 45872316', ['Rosa']) == '[NOMBRE] trae DNI [DOC]'),
  ];
}

class PaginaReglas extends StatefulWidget {
  const PaginaReglas({super.key});
  @override
  State<PaginaReglas> createState() => _PaginaReglasState();
}

class _PaginaReglasState extends State<PaginaReglas> {
  List<(String, String, bool)>? _res;

  void _ejecutar() {
    final s = Estado.de(context);
    final r = _pruebas().map((p) {
      bool ok;
      try {
        ok = p.f();
      } catch (_) {
        ok = false;
      }
      return (p.nombre, p.esperado, ok);
    }).toList();
    final integridad = s.verificarCadena() == null;
    r.add(('Integridad de la auditoría actual', 'Íntegra', integridad));
    setState(() => _res = r);
    s.marcarAutopruebas(r.where((x) => x.$3).length, r.length);
  }

  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    final res = _res;
    final pasan = res?.where((x) => x.$3).length ?? 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Encabezado('Reglas y pruebas', 'Cada campo hace exactamente lo que dice', sub: 'Todas las reglas de esta tabla están programadas. Las autopruebas son el paso «Pruebas» del ciclo DevOps.'),
        Tarjeta(
          titulo: 'Autopruebas',
          accion: FilledButton.icon(onPressed: _ejecutar, icon: const Icon(Icons.play_arrow), label: const Text('Ejecutar autopruebas')),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s.autopruebasOk == null ? 'Aún no hay una ejecución con 100 % de casos correctos (requisito para pasar versiones a QA).' : 'Última ejecución completa: ${hhmm(s.autopruebasOk!)}.', style: const TextStyle(color: Colores.tenue)),
            if (res != null) ...[
              const SizedBox(height: 8),
              Text('$pasan de ${res.length} pruebas superadas', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: pasan == res.length ? Colores.verde : Colores.rojo)),
              Tabla(['Caso', 'Esperado', 'Resultado'], [
                for (final x in res) [Text(x.$1), Text(x.$2), cumple(x.$3, si: '✓ correcto', no: '✗ falló')],
              ]),
            ],
          ]),
        ),
        Tarjeta(
          titulo: 'Reglas por campo',
          child: Tabla(['Módulo', 'Campo / función', 'Regla'], [
            for (final r in kReglas) [Text(r.$1), Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w700)), Text(r.$3)],
          ]),
        ),
      ]),
    );
  }
}
