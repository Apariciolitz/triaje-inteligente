import 'package:flutter/material.dart';
import '../core/datos.dart';
import '../core/modelo.dart';
import '../core/validadores.dart';
import '../estado/app_state.dart';
import '../estado/entidades.dart';
import '../estado/proveedor.dart';
import 'comunes.dart';

class PaginaTriaje extends StatefulWidget {
  const PaginaTriaje({super.key});
  @override
  State<PaginaTriaje> createState() => _PaginaTriajeState();
}

class _PaginaTriajeState extends State<PaginaTriaje> {
  String? _sel;
  bool _nuevo = false;

  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    final sala = s.enSala;
    final p = s.porId(_sel);
    final lista = Tarjeta(
      titulo: 'Pacientes en sala (${sala.length})',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (sala.isEmpty) const Text('No hay pacientes en sala.', style: TextStyle(color: Colores.tenue)),
        for (final x in sala)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() {
                _sel = x.id;
                _nuevo = false;
              }),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: x.id == _sel && !_nuevo ? Colores.azulS : Colors.white,
                  border: Border.all(color: x.id == _sel && !_nuevo ? Colores.navy : Colores.linea, width: x.id == _sel && !_nuevo ? 2 : 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(x.id, style: const TextStyle(fontWeight: FontWeight.w800))),
                    InsigniaPrioridad(x.decision?.prior),
                  ]),
                  Text('${x.edad != null ? '${x.edad} años' : '~${x.edadAprox} años'} · ${x.sexo} · llegó ${hhmm(x.llegadaTs)}${x.estado == 'en_atencion' ? ' · en ${x.topico}' : ''}', style: const TextStyle(color: Colores.tenue, fontSize: 12.5)),
                ]),
              ),
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _nuevo = true;
            _sel = null;
          }),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Registrar paciente'),
        ),
      ]),
    );
    Widget contenido;
    if (_nuevo) {
      contenido = FormRegistro(
        onGuardado: (id) => setState(() {
          _nuevo = false;
          _sel = id;
        }),
        onCancelar: () => setState(() => _nuevo = false),
      );
    } else if (p != null && p.enSala) {
      contenido = VistaPaciente(key: ValueKey('vp-${p.id}'), p: p, onCerrar: () => setState(() => _sel = null));
    } else {
      contenido = const Tarjeta(titulo: 'Sin paciente seleccionado', child: Text('Seleccione un paciente de la sala o pulse «Registrar paciente».', style: TextStyle(color: Colores.tenue)));
    }
    return LayoutBuilder(builder: (context, c) {
      final ancho = c.maxWidth >= 1000;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ancho
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 260, child: lista), const SizedBox(width: 16), Expanded(child: contenido)])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [lista, contenido]),
      );
    });
  }
}

/* ======================= Pasos ======================= */
class Pasos extends StatelessWidget {
  final Paciente? p;
  const Pasos(this.p, {super.key});
  @override
  Widget build(BuildContext context) {
    final x = p;
    final actual = x == null ? 0 : (x.estado != 'registrado' ? 4 : (x.tieneClinico ? 3 : 2));
    const nombres = ['Registro', 'Historia clínica', 'Motivo y signos', 'Sugerencia y decisión'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: i < actual ? Colores.verdeS : (i == actual ? Colores.azulS : const Color(0xFFF6F8FB)),
                border: Border.all(color: i < actual ? const Color(0xFFA5D6A7) : (i == actual ? Colores.navy : Colores.linea)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${i < actual ? '✓' : '${i + 1}.'} ${nombres[i]}', style: TextStyle(fontSize: 12.5, fontWeight: i == actual ? FontWeight.w800 : FontWeight.w500, color: i < actual ? const Color(0xFF1B5E20) : (i == actual ? Colores.navy : Colores.tenue))),
            ),
          ),
      ]),
    );
  }
}

/* ======================= Paso 1: registro ======================= */
class FormRegistro extends StatefulWidget {
  final ValueChanged<String> onGuardado;
  final VoidCallback onCancelar;
  const FormRegistro({super.key, required this.onGuardado, required this.onCancelar});
  @override
  State<FormRegistro> createState() => _FormRegistroState();
}

class _FormRegistroState extends State<FormRegistro> {
  TipoDoc _tipo = TipoDoc.dni;
  final _dni = TextEditingController(), _dv = TextEditingController(), _num = TextEditingController(), _nacOtra = TextEditingController();
  final _nom = TextEditingController(), _ap1 = TextEditingController(), _ap2 = TextEditingController(), _fnac = TextEditingController();
  final _edadAp = TextEditingController(), _senas = TextEditingController(), _hora = TextEditingController();
  final _aNom = TextEditingController(), _aCel = TextEditingController();
  PersonaPadron? _persona;
  bool _confirmado = false;
  String? _nac, _sexo, _llegada, _aPar;
  bool _acomp = false;
  Map<String, String> _e = {};
  bool _guardando = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hora.text.isEmpty) _hora.text = hhmm(Estado.de(context).ahora);
  }

  @override
  void dispose() {
    for (final c in [_dni, _dv, _num, _nacOtra, _nom, _ap1, _ap2, _fnac, _edadAp, _senas, _hora, _aNom, _aCel]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _edad(AppState s) {
    switch (_tipo) {
      case TipoDoc.dni:
        return _persona == null ? null : edadEn(_persona!.fnac, s.ahora);
      case TipoDoc.nn:
        return null; // en NN el acompañante es opcional
      default:
        final r = validarFechaNac(_fnac.text, s.ahora);
        return r.ok ? r.edad : null;
    }
  }

  void _limpiarError(String k) {
    if (_e.containsKey(k)) setState(() => _e = Map.of(_e)..remove(k));
  }

  void _verificar(AppState s) {
    final e = <String, String>{};
    final r = validarDNI(_dni.text, _dv.text);
    PersonaPadron? per;
    if (!r.ok) {
      e[r.mensaje!.contains('verificador') ? 'dv' : 'dni'] = r.mensaje!;
    } else {
      per = buscarPadron(r.valor!);
      if (per == null) {
        e['dni'] = 'El DNI tiene un formato y dígito verificador válidos, pero no figura en RENIEC (padrón simulado). Revise el número; si el paciente no puede identificarse, use «Sin documento».';
        s.registrarEvento('Consulta RENIEC sin resultado', detalle: 'Documento no encontrado');
      } else if (per.fallecido) {
        e['dni'] = 'Este DNI corresponde a una persona registrada como fallecida en RENIEC (padrón simulado). No se puede registrar: verifique la identidad del paciente.';
        s.registrarEvento('Consulta RENIEC: titular fallecido', detalle: 'Registro bloqueado');
        per = null;
      } else if (s.documentoActivo(TipoDoc.dni, per.dni)) {
        e['dni'] = 'Este paciente ya tiene una atención activa en sala. No se permite un registro duplicado.';
        per = null;
      }
    }
    setState(() {
      _e = e;
      _persona = per;
      _confirmado = false;
      if (per != null && edadEn(per.fnac, s.ahora) < 18) _acomp = true;
    });
  }

  void _guardar(AppState s) {
    if (_guardando) return;
    final e = <String, String>{};
    final ahora = s.ahora;
    String? docNum, dv, nombres, ap1, ap2, sexo, nacionalidad, senas, seguro;
    DateTime? fnac;
    int? edad, edadAprox;
    HistoriaClinica? hc;
    switch (_tipo) {
      case TipoDoc.dni:
        final r = validarDNI(_dni.text, _dv.text);
        if (!r.ok) {
          e[r.mensaje!.contains('verificador') ? 'dv' : 'dni'] = r.mensaje!;
        } else if (_persona == null || _persona!.dni != r.valor) {
          e['dni'] = 'Pulse «Verificar en RENIEC (simulado)» antes de registrar.';
        } else if (!_confirmado) {
          e['conf'] = 'Debe confirmar que la persona presente coincide con el documento.';
        } else {
          final x = _persona!;
          docNum = x.dni;
          dv = _dv.text.trim().toUpperCase();
          nombres = x.nombres;
          ap1 = x.ap1;
          ap2 = x.ap2;
          sexo = x.sexo;
          fnac = x.fnac;
          edad = edadEn(x.fnac, ahora);
          seguro = x.seguroActivo ? 'Activo' : 'Inactivo';
          hc = x.hc;
        }
        break;
      case TipoDoc.nn:
        if (_sexo == null) e['sexo'] = 'Seleccione el sexo.';
        final ea = validarEnteroRango(_edadAp.text, 0, 120, 'la edad aproximada');
        if (!ea.ok) e['edadAp'] = ea.mensaje!;
        final se = validarTexto(_senas.text, 10, 200, 'las señas particulares');
        if (!se.ok) e['senas'] = se.mensaje!;
        sexo = _sexo;
        edadAprox = ea.valor;
        senas = se.valor;
        seguro = 'Por verificar';
        break;
      case TipoDoc.ce:
      case TipoDoc.pasaporte:
        final n = _tipo == TipoDoc.ce ? validarCE(_num.text) : validarPasaporte(_num.text);
        if (!n.ok) {
          e['num'] = n.mensaje!;
        } else if (s.documentoActivo(_tipo, n.valor!)) {
          e['num'] = 'Este documento ya tiene una atención activa en sala. No se permite un registro duplicado.';
        }
        if (_tipo == TipoDoc.pasaporte) {
          if (_nac == null) {
            e['nac'] = 'Seleccione la nacionalidad.';
          } else if (_nac == 'Otra') {
            final o = validarNombre(_nacOtra.text, 'la nacionalidad');
            if (!o.ok) e['nacOtra'] = o.mensaje!;
            nacionalidad = o.valor;
          } else {
            nacionalidad = _nac;
          }
        }
        final no = validarNombre(_nom.text, 'los nombres');
        if (!no.ok) e['nom'] = no.mensaje!;
        final a1 = validarNombre(_ap1.text, 'el primer apellido');
        if (!a1.ok) e['ap1'] = a1.mensaje!;
        if (_ap2.text.trim().isNotEmpty) {
          final a2 = validarNombre(_ap2.text, 'el segundo apellido');
          if (!a2.ok) e['ap2'] = a2.mensaje!;
          ap2 = a2.valor;
        }
        if (_sexo == null) e['sexo'] = 'Seleccione el sexo.';
        final fn = validarFechaNac(_fnac.text, ahora);
        if (!fn.ok) e['fnac'] = fn.mensaje!;
        docNum = n.valor;
        nombres = no.valor;
        ap1 = a1.valor;
        sexo = _sexo;
        fnac = fn.valor;
        edad = fn.edad;
        seguro = 'No asegurado (documento extranjero)';
        break;
    }
    if (_llegada == null) e['llegada'] = 'Seleccione la forma de llegada.';
    final h = validarHora(_hora.text, ahora);
    if (!h.ok) e['hora'] = h.mensaje!;
    Acompanante? acomp;
    final ed = _edad(s);
    final menor = ed != null && ed < 18;
    if (_acomp || menor) {
      final an = validarNombre(_aNom.text, 'el nombre del acompañante');
      if (!an.ok) {
        e['aNom'] = an.mensaje!;
      } else if (an.valor!.split(' ').length < 2) {
        e['aNom'] = 'Ingrese nombre y apellido del acompañante (al menos dos palabras).';
      }
      if (_aPar == null) e['aPar'] = 'Seleccione el parentesco.';
      final ac = validarCelular(_aCel.text);
      if (!ac.ok) e['aCel'] = ac.mensaje!;
      if (an.ok && _aPar != null && ac.ok) acomp = Acompanante(an.valor!, _aPar!, ac.valor!);
    }
    setState(() => _e = e);
    if (e.isNotEmpty) {
      aviso(context, 'Hay ${e.length} campo(s) por corregir.', error: true);
      return;
    }
    _guardando = true;
    final p = s.registrar(tipo: _tipo, docNum: docNum, dv: dv, nombres: nombres, ap1: ap1, ap2: ap2, sexo: sexo!, fnac: fnac, edad: edad, edadAprox: edadAprox, seguro: seguro!, nacionalidad: nacionalidad, senas: senas, hc: hc, acompanante: acomp, llegada: _llegada!, llegadaTs: h.valor!);
    aviso(context, 'Paciente ${p.id} registrado${hc != null ? ' · historia clínica cargada' : ''}.');
    widget.onGuardado(p.id);
  }

  Future<void> _elegirFecha(AppState s) async {
    final hoy = s.ahora;
    final f = await showDatePicker(context: context, initialDate: DateTime(hoy.year - 30), firstDate: DateTime(hoy.year - 120), lastDate: hoy, helpText: 'Fecha de nacimiento');
    if (f != null) {
      setState(() {
        _fnac.text = '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
        _e = Map.of(_e)..remove('fnac');
      });
    }
  }

  Future<void> _elegirHora(AppState s) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(s.ahora));
    if (t != null) {
      setState(() {
        _hora.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        _e = Map.of(_e)..remove('hora');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    final ed = _edad(s);
    final menor = ed != null && ed < 18;
    final form = Tarjeta(
      titulo: '1. Registro del paciente',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ResumenErrores(_e),
        Lista<TipoDoc>('Tipo de documento', requerido: true, valor: _tipo, opciones: TipoDoc.values, texto: tipoDocTexto,
            ayuda: 'En emergencia no se niega la atención por falta de documento: use «Sin documento» si el paciente no puede identificarse.',
            alCambiar: (v) => setState(() {
                  _tipo = v ?? TipoDoc.dni;
                  _persona = null;
                  _confirmado = false;
                  _acomp = false;
                  _e = {};
                })),
        ..._camposDocumento(s),
        const Divider(height: 24),
        Lista<String>('Forma de llegada', requerido: true, valor: _llegada, opciones: kFormasLlegada, texto: (x) => x, error: _e['llegada'], alCambiar: (v) => setState(() {
              _llegada = v;
              _e = Map.of(_e)..remove('llegada');
            })),
        Campo(_hora, 'Hora de llegada (HH:MM)', requerido: true, error: _e['hora'], ayuda: 'No puede ser futura ni de hace más de 12 h.', teclado: TextInputType.datetime, formatos: [Formatos.hora, Formatos.largo(5)], alCambiar: (_) => _limpiarError('hora'),
            sufijo: IconButton(tooltip: 'Elegir hora', icon: const Icon(Icons.schedule), onPressed: () => _elegirHora(s))),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('¿Viene con acompañante?'),
          subtitle: Text(menor ? 'Obligatorio: el paciente es menor de edad.' : 'Obligatorio si el paciente es menor de 18 años.', style: TextStyle(color: menor ? Colores.ambar : Colores.tenue)),
          value: _acomp || menor,
          onChanged: menor ? null : (v) => setState(() => _acomp = v),
        ),
        if (_acomp || menor) ...[
          Campo(_aNom, 'Nombres y apellidos del acompañante', requerido: true, error: _e['aNom'], maxLength: 60, ayuda: 'Al menos nombre y apellido.', mayus: TextCapitalization.words, alCambiar: (_) => _limpiarError('aNom')),
          Lista<String>('Parentesco', requerido: true, valor: _aPar, opciones: kParentescos, texto: (x) => x, error: _e['aPar'], alCambiar: (v) => setState(() {
                _aPar = v;
                _e = Map.of(_e)..remove('aPar');
              })),
          Campo(_aCel, 'Celular de contacto', requerido: true, error: _e['aCel'], pista: '9XXXXXXXX', teclado: TextInputType.phone, formatos: [Formatos.digitos, Formatos.largo(9)], alCambiar: (_) => _limpiarError('aCel')),
        ],
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.end, spacing: 10, children: [
          OutlinedButton(onPressed: widget.onCancelar, child: const Text('Cancelar')),
          FilledButton.icon(onPressed: () => _guardar(s), icon: const Icon(Icons.save), label: const Text('Registrar paciente')),
        ]),
      ]),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Pasos(null),
      form,
      if (_persona != null) TarjetaHistoria.desdePadron(_persona!),
    ]);
  }

  List<Widget> _camposDocumento(AppState s) {
    if (_tipo == TipoDoc.dni) {
        return [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 3,
              child: Campo(_dni, 'Número de DNI', requerido: true, error: _e['dni'], pista: '8 dígitos', teclado: TextInputType.number, formatos: [Formatos.digitos, Formatos.largo(8)], alCambiar: (_) {
                setState(() {
                  _persona = null;
                  _confirmado = false;
                  _e = Map.of(_e)..remove('dni');
                });
              }),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Campo(_dv, 'Dígito verificador', requerido: true, error: _e['dv'], pista: '0-9 o A-K', formatos: [Formatos.dv, Formatos.largo(1), Formatos.mayusculas], alCambiar: (_) {
                setState(() {
                  _persona = null;
                  _confirmado = false;
                  _e = Map.of(_e)..remove('dv');
                });
              }),
            ),
          ]),
          const Text('El dígito verificador es el carácter que figura después del guion en el DNI (por ejemplo, 45872316 - 3).', style: TextStyle(color: Colores.tenue, fontSize: 12)),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed: () => _verificar(s), icon: const Icon(Icons.verified_user_outlined), label: const Text('Verificar en RENIEC (simulado)'))),
          if (_persona != null) ...[
            Aviso(
              TipoAviso.ok,
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('DNI verificado: ${_persona!.nombreCompleto}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${_persona!.sexo == 'F' ? 'Femenino' : 'Masculino'} · ${edadEn(_persona!.fnac, s.ahora)} años'),
                Text(_persona!.seguroActivo ? 'Seguro: asegurado activo' : 'Seguro: NO asegurado / inactivo. Se atiende la emergencia igualmente.', style: TextStyle(fontWeight: FontWeight.w700, color: _persona!.seguroActivo ? null : Colores.rojo)),
              ]),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _confirmado,
              onChanged: (v) => setState(() {
                _confirmado = v ?? false;
                _e = Map.of(_e)..remove('conf');
              }),
              title: const Text('Confirmo que la persona presente coincide con los datos y la foto del documento.'),
              subtitle: _e['conf'] == null ? null : Text(_e['conf']!, style: const TextStyle(color: Colores.rojo)),
            ),
          ],
        ];
    }
    if (_tipo == TipoDoc.nn) {
        return [
          Aviso.texto(TipoAviso.info, 'Se generará un código temporal NN. La identidad se completará cuando sea posible; no habrá historia clínica vinculada.'),
          Lista<String>('Sexo', requerido: true, valor: _sexo, opciones: const ['M', 'F', 'Indeterminado'], texto: (x) => x, error: _e['sexo'], alCambiar: (v) => setState(() {
                _sexo = v;
                _e = Map.of(_e)..remove('sexo');
              })),
          Campo(_edadAp, 'Edad aproximada (años)', requerido: true, error: _e['edadAp'], ayuda: 'Entero de 0 a 120.', teclado: TextInputType.number, formatos: [Formatos.digitos, Formatos.largo(3)], alCambiar: (_) => _limpiarError('edadAp')),
          Campo(_senas, 'Señas particulares y circunstancia', requerido: true, error: _e['senas'], lineas: 2, maxLength: 200, pista: 'Ej.: varón delgado, polo azul, traído por serenazgo desde la vía pública', alCambiar: (_) => _limpiarError('senas')),
        ];
    }
    final ce = _tipo == TipoDoc.ce;
        return [
          Campo(_num, ce ? 'Número de carné de extranjería' : 'Número de pasaporte', requerido: true, error: _e['num'], ayuda: ce ? '8 a 12 letras o números.' : '6 a 12 letras o números.', formatos: [Formatos.alfanum, Formatos.largo(12), Formatos.mayusculas], alCambiar: (_) => _limpiarError('num')),
          if (!ce)
            Lista<String>('Nacionalidad', requerido: true, valor: _nac, opciones: kNacionalidades, texto: (x) => x, error: _e['nac'], alCambiar: (v) => setState(() {
                  _nac = v;
                  _e = Map.of(_e)..remove('nac');
                })),
          if (!ce && _nac == 'Otra') Campo(_nacOtra, 'Especifique la nacionalidad', requerido: true, error: _e['nacOtra'], maxLength: 40, alCambiar: (_) => _limpiarError('nacOtra')),
          Campo(_nom, 'Nombres', requerido: true, error: _e['nom'], maxLength: 40, mayus: TextCapitalization.words, alCambiar: (_) => _limpiarError('nom')),
          Campo(_ap1, 'Primer apellido', requerido: true, error: _e['ap1'], maxLength: 40, mayus: TextCapitalization.words, alCambiar: (_) => _limpiarError('ap1')),
          Campo(_ap2, 'Segundo apellido', error: _e['ap2'], ayuda: 'Opcional.', maxLength: 40, mayus: TextCapitalization.words, alCambiar: (_) => _limpiarError('ap2')),
          Lista<String>('Sexo', requerido: true, valor: _sexo, opciones: const ['M', 'F'], texto: (x) => x == 'M' ? 'Masculino' : 'Femenino', error: _e['sexo'], alCambiar: (v) => setState(() {
                _sexo = v;
                _e = Map.of(_e)..remove('sexo');
              })),
          Campo(_fnac, 'Fecha de nacimiento (DD/MM/AAAA)', requerido: true, error: _e['fnac'], pista: 'DD/MM/AAAA', teclado: TextInputType.datetime, formatos: [Formatos.fecha, Formatos.largo(10)], alCambiar: (_) => setState(() => _e = Map.of(_e)..remove('fnac')),
              sufijo: IconButton(tooltip: 'Elegir fecha', icon: const Icon(Icons.calendar_month), onPressed: () => _elegirFecha(s))),
          Aviso.texto(TipoAviso.alerta, 'Documento extranjero: no se consulta RENIEC ni la historia clínica de EsSalud. Verifique los datos con el documento físico.'),
        ];
  }
}

/* ======================= Historia clínica ======================= */
class TarjetaHistoria extends StatelessWidget {
  final HistoriaClinica? hc;
  final String? dni;
  final String? aviso;
  const TarjetaHistoria({super.key, this.hc, this.dni, this.aviso});
  factory TarjetaHistoria.desdePadron(PersonaPadron p) => TarjetaHistoria(hc: p.hc, dni: p.dni, aviso: p.hc == null ? 'Sin historia clínica en EsSalud (no asegurado). Pregunte por alergias y antecedentes.' : null);
  factory TarjetaHistoria.de(Paciente p) {
    if (p.tipo == TipoDoc.nn) return TarjetaHistoria(aviso: 'Paciente no identificado (${p.docNum}). Sin historia clínica vinculada. Señas: ${p.senas ?? '—'}');
    if (p.hc == null) return TarjetaHistoria(aviso: 'Sin historia clínica en EsSalud (${p.seguro}). Pregunte por alergias y antecedentes al paciente o acompañante.');
    return TarjetaHistoria(hc: p.hc, dni: p.dv == null ? p.docNum : '${p.docNum}-${p.dv}');
  }
  @override
  Widget build(BuildContext context) {
    final h = hc;
    return Tarjeta(
      titulo: 'Historia clínica digital',
      accion: h == null ? null : const Text('✓ consultada', style: TextStyle(color: Colores.verde, fontWeight: FontWeight.w700, fontSize: 12)),
      child: h == null
          ? Aviso.texto(TipoAviso.alerta, aviso ?? 'Sin historia clínica.')
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (h.diagnosticos.isEmpty) const Text('Sin diagnósticos crónicos registrados.', style: TextStyle(color: Colores.tenue)),
                for (final d in h.diagnosticos) Chip(label: Text('${d.cod} · ${d.nombre}'), visualDensity: VisualDensity.compact),
              ]),
              if (dni != null) KV('DNI (ficticio)', dni!),
              KV('Alergias', h.alergias.isEmpty ? 'Ninguna registrada' : h.alergias.join(', '), color: h.alergias.isEmpty ? null : Colores.rojo),
              KV('Medicación habitual', h.medicacion.isEmpty ? 'Ninguna' : h.medicacion.join(' · ')),
              KV('Hospitalizaciones (12 meses)', '${h.hospAnio}'),
              KV('Última emergencia', h.ultEmergDias == null ? 'Sin registro' : 'Hace ${h.ultEmergDias} días (${h.ultEmergMotivo})'),
            ]),
    );
  }
}

/* ======================= Paciente seleccionado ======================= */
class VistaPaciente extends StatelessWidget {
  final Paciente p;
  final VoidCallback onCerrar;
  const VistaPaciente({super.key, required this.p, required this.onCerrar});

  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    final datos = Tarjeta(
      titulo: 'Paciente ${p.id}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (p.tipo != TipoDoc.nn) KV('Nombre', p.nombreCompleto),
        KV('Edad / sexo', '${p.edad != null ? '${p.edad} años' : '~${p.edadAprox} años (aprox.)'} · ${p.sexo}'),
        KV('Llegada', '${hhmm(p.llegadaTs)} (hace ${s.ahora.difference(p.llegadaTs).inMinutes} min) · ${p.llegada}'),
        KV('Seguro', p.seguro, color: p.seguro == 'Activo' ? null : Colores.ambar),
        if (p.acompanante != null) KV('Acompañante', '${p.acompanante!.nombre} (${p.acompanante!.parentesco}) · ${p.acompanante!.celular}'),
        KV('Código seudónimo', p.seudo),
      ]),
    );
    final izquierda = <Widget>[datos];
    final derecha = <Widget>[TarjetaHistoria.de(p)];
    if (p.estado == 'registrado') {
      izquierda.add(FormClinico(key: ValueKey('fc-${p.id}'), p: p));
      if (p.tieneClinico) derecha.add(PanelDecision(key: ValueKey('pd-${p.id}-${p.preds.length}'), p: p));
      derecha.add(Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colores.rojo),
          onPressed: () async {
            final m = await pedirTexto(context, 'Anular registro ${p.id}', 'Motivo de la anulación', (t) {
              final r = validarTexto(t, 15, 200, 'el motivo');
              return r.ok ? null : r.mensaje;
            }, descripcion: 'Solo para registros duplicados o con error. No se borra: queda en la auditoría.', boton: 'Anular');
            if (m != null) {
              s.anular(p, m);
              onCerrar();
              if (context.mounted) aviso(context, 'Registro ${p.id} anulado.');
            }
          },
          icon: const Icon(Icons.block),
          label: const Text('Anular registro (error o duplicado)'),
        ),
      ));
    } else {
      izquierda.add(_resumenClinico());
      izquierda.add(_acciones(context, s));
      derecha.add(_resumenDecision(s));
    }
    return LayoutBuilder(builder: (context, c) {
      final dos = c.maxWidth >= 900;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Pasos(p),
        if (dos)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: izquierda)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: derecha)),
          ])
        else
          ...[...izquierda, ...derecha],
      ]);
    });
  }

  Widget _resumenClinico() => Tarjeta(
        titulo: 'Motivo y signos vitales',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(p.motivo ?? ''),
          if (p.gestante != null) KV('Gestante', p.gestante!),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final d in kVitales) Chip(visualDensity: VisualDensity.compact, label: Text('${d.corto}: ${p.vit[d.id] == null ? 'no medido' : '${fmtNum(p.vit[d.id]!)} ${d.unidad}'}')),
          ]),
        ]),
      );

  Widget _resumenDecision(AppState s) {
    final d = p.decision!;
    final esperando = s.ahora.difference(p.prioridadTs!).inMinutes;
    final lim = pr(d.prior).limiteMin;
    return Tarjeta(
      titulo: 'Decisión registrada',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CajaPrioridad(d.prior, ancho: 130),
          const SizedBox(width: 12),
          Expanded(
            child: Column(children: [
              KV('Profesional', d.profesional),
              KV('Hora', '${hhmm(d.ts)} (${d.ts.difference(p.llegadaTs).inMinutes} min desde la llegada)'),
              KV('Modo', d.modo == 'sombra' ? 'Modo sombra' : 'Piloto asistido'),
              KV('Sugerencia mostrada', d.sugeridaVisible == null ? 'No se mostró (modo sombra)' : '${pr(d.sugeridaVisible!).romano} ${d.priorInicial == d.sugeridaVisible ? '(coincide)' : '(discrepancia)'}'),
              if (d.motivoTxt != null) KV('Motivo del cambio', '${d.motivoCat}: ${d.motivoTxt}'),
            ]),
          ),
        ]),
        if (p.estado == 'clasificado' && d.prior > 1 && esperando > lim) Aviso.texto(TipoAviso.alerta, 'Revaluar ahora: lleva $esperando min en espera desde su clasificación; el tiempo de referencia para Prioridad ${pr(d.prior).romano} es $lim min.'),
        if (p.revaloraciones.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Revaloraciones', style: TextStyle(fontWeight: FontWeight.w800, color: Colores.teal)),
          for (final r in p.revaloraciones) KV('${hhmm(r.ts)} · ${pr(r.de).romano} → ${pr(r.a).romano}', r.motivo),
        ],
      ]),
    );
  }

  Widget _acciones(BuildContext context, AppState s) {
    if (s.rol == Rol.comite) return const SizedBox.shrink();
    if (p.estado == 'clasificado') {
      final libre = s.topicoLibre();
      return Tarjeta(
        titulo: 'Acciones',
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          OutlinedButton.icon(onPressed: () => _revalorar(context, s), icon: const Icon(Icons.update), label: const Text('Revalorar prioridad')),
          FilledButton.icon(
            onPressed: libre == null ? null : () => enviarATopico(context, s, p),
            icon: const Icon(Icons.meeting_room_outlined),
            label: Text(libre == null ? 'No hay tópicos libres' : 'Enviar a tópico T${libre + 1}'),
          ),
        ]),
      );
    }
    if (p.estado == 'en_atencion') {
      return Tarjeta(
        titulo: 'Acciones',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('En atención en ${p.topico} desde ${hhmm(p.inicioTs!)}.'),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colores.verde),
            onPressed: () {
              s.finalizarAtencion(p);
              aviso(context, 'Atención de ${p.id} finalizada; tópico liberado.');
            },
            icon: const Icon(Icons.check),
            label: const Text('Finalizar atención y liberar tópico'),
          ),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _revalorar(BuildContext context, AppState s) async {
    final actual = p.decision!.prior;
    int? nueva;
    final ctrl = TextEditingController();
    String? ePri, eTxt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('Revalorar ${p.id}'),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Lista<int>('Nueva prioridad', requerido: true, valor: nueva, opciones: [1, 2, 3, 4].where((n) => n != actual).toList(), texto: (n) => '${pr(n).romano} · ${pr(n).nombre}', error: ePri, alCambiar: (v) => set(() {
                    nueva = v;
                    ePri = null;
                  })),
              TextField(controller: ctrl, minLines: 2, maxLines: 4, maxLength: 300, decoration: InputDecoration(labelText: 'Motivo de la revaloración *', helperText: 'Entre 15 y 300 caracteres.', errorText: eTxt)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final r = validarTexto(ctrl.text, 15, 300, 'el motivo');
                set(() {
                  ePri = nueva == null ? 'Seleccione la nueva prioridad.' : null;
                  eTxt = r.ok ? null : r.mensaje;
                });
                if (nueva != null && r.ok) Navigator.pop(ctx, true);
              },
              child: const Text('Guardar revaloración'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && nueva != null) {
      s.revalorar(p, nueva!, validarTexto(ctrl.text, 15, 300, 'el motivo').valor!);
      if (context.mounted) aviso(context, 'Revaloración registrada.');
    }
  }
}

/// Envía al tópico libre; si hay pacientes más urgentes esperando, pide confirmación.
Future<void> enviarATopico(BuildContext context, AppState s, Paciente p) async {
  final urg = s.masUrgentesEsperando(p);
  if (urg.isNotEmpty) {
    final ok = await confirmar(context, 'Hay pacientes más urgentes esperando', '${urg.map((e) => e.id).join(', ')} tiene(n) una prioridad más urgente que ${p.id}. ¿Enviar igualmente a ${p.id}? Quedará registrado en la auditoría.');
    if (!ok) return;
  }
  s.enviarATopico(p);
  if (context.mounted) aviso(context, '${p.id} enviado a ${p.topico}.');
}

/* ======================= Paso 3: motivo y signos ======================= */
class FormClinico extends StatefulWidget {
  final Paciente p;
  const FormClinico({super.key, required this.p});
  @override
  State<FormClinico> createState() => _FormClinicoState();
}

class _FormClinicoState extends State<FormClinico> {
  final _motivo = TextEditingController();
  final Map<String, TextEditingController> _v = {for (final d in kVitales) d.id: TextEditingController()};
  final Map<String, bool> _nm = {for (final d in kVitales) d.id: false};
  final Map<String, String?> _nmMotivo = {for (final d in kVitales) d.id: null};
  String? _gest;
  bool _critOk = false;
  Map<String, String> _e = {};

  @override
  void initState() {
    super.initState();
    final p = widget.p;
    _motivo.text = p.motivo ?? '';
    _gest = p.gestante;
    for (final d in kVitales) {
      _v[d.id]!.text = p.vitRaw[d.id] ?? '';
      if (p.noMedido.containsKey(d.id)) {
        _nm[d.id] = true;
        _nmMotivo[d.id] = p.noMedido[d.id];
      }
    }
  }

  @override
  void dispose() {
    _motivo.dispose();
    for (final c in _v.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _pideGestante {
    final p = widget.p;
    final e = p.edadEfectiva;
    return p.sexo == 'F' && e != null && e >= 10 && e <= 55;
  }

  List<VitalDef> _criticos() => kVitales.where((d) {
        if (_nm[d.id]!) return false;
        final r = validarVital(d, _v[d.id]!.text);
        return r.ok && r.critico;
      }).toList();

  void _guardar(AppState s) {
    final e = <String, String>{};
    final m = validarMotivo(_motivo.text);
    if (!m.ok) e['motivo'] = m.mensaje!;
    if (_pideGestante && _gest == null) e['gest'] = 'Indique si la paciente está gestante.';
    final vit = <String, double?>{};
    final raw = <String, String>{};
    final nm = <String, String>{};
    var noMed = 0;
    for (final d in kVitales) {
      if (_nm[d.id]!) {
        noMed++;
        vit[d.id] = null;
        if (_nmMotivo[d.id] == null) {
          e['v-${d.id}'] = '${d.nombre}: seleccione el motivo por el que no se midió.';
        } else {
          nm[d.id] = _nmMotivo[d.id]!;
        }
        continue;
      }
      raw[d.id] = _v[d.id]!.text;
      final r = validarVital(d, _v[d.id]!.text);
      if (r.ok) {
        vit[d.id] = r.valor;
      } else {
        e['v-${d.id}'] = r.mensaje!;
      }
    }
    if (noMed > 3) e['nm'] = 'Hay $noMed signos marcados como «No medido»; el máximo es 3. Registre al menos ${kVitales.length - 3} signos.';
    validarVitalesCruzado(vit).forEach((k, msg) => e.putIfAbsent('v-$k', () => msg));
    final crit = kVitales.any((d) => vit[d.id] != null && d.critico(vit[d.id]!));
    if (crit && !_critOk) e['crit'] = 'Confirme que volvió a medir los valores críticos.';
    setState(() => _e = e);
    if (e.isNotEmpty) {
      aviso(context, 'Hay ${e.length} campo(s) por corregir.', error: true);
      return;
    }
    s.guardarClinico(widget.p, motivo: m.valor!, gestante: _pideGestante ? _gest : null, vit: vit, noMedido: nm, vitRaw: raw);
    aviso(context, s.modoPiloto ? 'Sugerencia calculada.' : 'Datos guardados. Registre la decisión profesional (modo sombra).');
  }

  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    final p = widget.p;
    final terminos = analizarTexto(_motivo.text);
    final crit = _criticos();
    return Tarjeta(
      titulo: '3. Motivo de consulta y signos vitales',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ResumenErrores(_e),
        Campo(_motivo, 'Motivo de consulta (texto libre)', requerido: true, error: _e['motivo'], lineas: 3, maxLength: 500,
            ayuda: 'Mínimo 10 caracteres y dos palabras. No escriba nombres ni números de documento: se filtran antes de enviarse a la nube.',
            alCambiar: (_) => setState(() => _e = Map.of(_e)..remove('motivo'))),
        if (_motivo.text.trim().isNotEmpty) ...[
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('PLN · términos detectados:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            if (terminos.isEmpty) const Text('ninguno (el texto se usará igual)', style: TextStyle(color: Colores.tenue, fontSize: 12.5)),
            for (final t in terminos) Chip(visualDensity: VisualDensity.compact, backgroundColor: Colores.menta, label: Text(t.grupo.categoria, style: const TextStyle(fontSize: 12))),
          ]),
          const SizedBox(height: 4),
          Text('Texto seudonimizado que se enviaría a la nube: ${filtrarTexto(_motivo.text, p.partesNombre)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colores.tenue)),
          const SizedBox(height: 10),
        ],
        if (_pideGestante)
          Lista<String>('¿Gestante?', requerido: true, valor: _gest, opciones: const ['No', 'Sí', 'Desconoce'], texto: (x) => x, error: _e['gest'], alCambiar: (v) => setState(() {
                _gest = v;
                _e = Map.of(_e)..remove('gest');
              })),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 640 ? 4 : 2;
          final w = (c.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(spacing: 10, runSpacing: 4, children: [for (final d in kVitales) SizedBox(width: w, child: _vital(d))]);
        }),
        if (_e['nm'] != null) Text(_e['nm']!, style: const TextStyle(color: Colores.rojo, fontSize: 12.5)),
        const Text('Ingreso manual. Captura automática con IoT: fase posterior. Máximo 3 signos «No medido».', style: TextStyle(color: Colores.tenue, fontSize: 12)),
        if (crit.isNotEmpty)
          Aviso(
            TipoAviso.alerta,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Valores críticos: ${crit.map((d) => '${d.nombre} ${_v[d.id]!.text} ${d.unidad}').join(', ')}.', style: const TextStyle(fontWeight: FontWeight.w700)),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _critOk,
                onChanged: (v) => setState(() {
                  _critOk = v ?? false;
                  _e = Map.of(_e)..remove('crit');
                }),
                title: const Text('Confirmo que volví a medir y los valores críticos son correctos.'),
                subtitle: _e['crit'] == null ? null : Text(_e['crit']!, style: const TextStyle(color: Colores.rojo)),
              ),
            ]),
          ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: s.rol == Rol.comite ? null : () => _guardar(s),
            icon: Icon(s.modoPiloto ? Icons.auto_awesome : Icons.arrow_forward),
            label: Text(p.tieneClinico ? 'Actualizar datos clínicos' : (s.modoPiloto ? 'Obtener sugerencia del sistema' : 'Continuar a la decisión profesional')),
          ),
        ),
      ]),
    );
  }

  Widget _vital(VitalDef d) {
    final nm = _nm[d.id]!;
    String? flag;
    Color? flagColor;
    if (!nm && _v[d.id]!.text.trim().isNotEmpty) {
      final r = validarVital(d, _v[d.id]!.text);
      if (r.ok && r.critico) {
        flag = '⚠ Valor crítico';
        flagColor = Colores.rojo;
      } else if (r.ok && r.alerta) {
        flag = 'Valor alterado';
        flagColor = Colores.ambar;
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _v[d.id],
        enabled: !nm,
        keyboardType: TextInputType.numberWithOptions(decimal: d.decimales > 0),
        inputFormatters: [d.decimales > 0 ? Formatos.decimal : Formatos.digitos, Formatos.largo(d.decimales > 0 ? 5 : 3)],
        onChanged: (_) => setState(() => _e = Map.of(_e)..remove('v-${d.id}')),
        decoration: InputDecoration(labelText: '${d.corto} (${d.unidad}) *', errorText: _e['v-${d.id}'], errorMaxLines: 6, helperText: flag, helperStyle: TextStyle(color: flagColor, fontWeight: FontWeight.w700)),
      ),
      Row(children: [
        SizedBox(
          width: 32,
          child: Checkbox(
            value: nm,
            onChanged: (v) => setState(() {
              _nm[d.id] = v ?? false;
              if (v == true) _v[d.id]!.clear();
              if (v != true) _nmMotivo[d.id] = null;
              _e = Map.of(_e)
                ..remove('v-${d.id}')
                ..remove('nm');
            }),
          ),
        ),
        const Text('No medido', style: TextStyle(fontSize: 12.5)),
      ]),
      if (nm)
        DropdownButton<String>(
          isExpanded: true,
          value: _nmMotivo[d.id],
          hint: const Text('Motivo…', style: TextStyle(fontSize: 12.5)),
          items: kMotivosNoMedido.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() {
            _nmMotivo[d.id] = v;
            _e = Map.of(_e)..remove('v-${d.id}');
          }),
        ),
      const SizedBox(height: 6),
    ]);
  }
}

/* ======================= Paso 4: sugerencia y decisión ======================= */
class PanelDecision extends StatefulWidget {
  final Paciente p;
  const PanelDecision({super.key, required this.p});
  @override
  State<PanelDecision> createState() => _PanelDecisionState();
}

class _PanelDecisionState extends State<PanelDecision> {
  bool _modificando = false;
  int? _nueva;
  String? _cat;
  bool _bajaOk = false;
  final _txt = TextEditingController();
  Map<String, String> _e = {};

  @override
  void dispose() {
    _txt.dispose();
    super.dispose();
  }

  void _confirmarCambio(AppState s, Prediccion sug) {
    final e = <String, String>{};
    if (_nueva == null) e['nueva'] = 'Seleccione la nueva prioridad.';
    if (_cat == null) e['cat'] = 'Seleccione el motivo del cambio.';
    final t = validarTexto(_txt.text, 15, 300, 'el detalle del motivo');
    if (!t.ok) e['txt'] = t.mensaje!;
    if (_nueva != null && _nueva! > sug.prioridad && !_bajaOk) e['baja'] = 'Debe confirmar la reevaluación para asignar una prioridad menos urgente que la sugerida.';
    setState(() => _e = e);
    if (e.isNotEmpty) return;
    s.decidir(widget.p, prior: _nueva!, aceptada: false, motivoCat: _cat, motivoTxt: t.valor);
    aviso(context, '${widget.p.id} clasificado como Prioridad ${pr(_nueva!).romano}.');
  }

  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    final p = widget.p;
    if (s.rol == Rol.comite) return const SizedBox.shrink();
    final sug = s.sugerenciaVisible(p);
    if (!s.modoPiloto) return _sombra(s);
    if (sug == null) {
      return Tarjeta(
        titulo: 'Sugerencia del sistema',
        child: Aviso.texto(TipoAviso.alerta, 'La versión en producción cambió después de registrar los datos. Pulse «Actualizar datos clínicos» para recalcular la sugerencia con la versión vigente.'),
      );
    }
    final maxW = sug.contribuciones.fold<double>(1, (m, c) => c.peso.abs() > m ? c.peso.abs() : m);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Tarjeta(
        titulo: 'Sugerencia del sistema · v${sug.version}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            CajaPrioridad(sug.prioridad, titulo: 'Prioridad sugerida'),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Riesgo estimado de desenlace crítico a 24 h (demostración): ${fmt(sug.prob * 100, 1)} %', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: sug.prob, minHeight: 10, color: const Color(0xFFE65100), backgroundColor: const Color(0xFFE7EBF1))),
                const SizedBox(height: 6),
                const Text('El sistema solo sugiere; decide el profesional.', style: TextStyle(color: Colores.tenue, fontSize: 12)),
              ]),
            ),
          ]),
          if (sug.reglas.isNotEmpty)
            Aviso.texto(TipoAviso.alerta, 'Regla de seguridad clínica aplicada (no la decide el modelo): ${sug.reglas.map((r) => 'prioridad mínima ${pr(r.minimo).romano} por ${r.motivo}').join('; ')}. El modelo por sí solo estimaba Prioridad ${pr(sug.prioridadModelo).romano}.'),
          const SizedBox(height: 8),
          const Text('MOTIVOS DE LA SUGERENCIA', style: TextStyle(fontWeight: FontWeight.w800, color: Colores.teal, fontSize: 12.5, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          if (sug.contribuciones.isEmpty) const Text('Sin factores de riesgo detectados.', style: TextStyle(color: Colores.tenue)),
          for (final c in sug.contribuciones)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(
                  width: 90,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (c.peso.abs() / maxW).clamp(0.05, 1.0).toDouble(),
                      child: Container(height: 8, decoration: BoxDecoration(color: c.peso < 0 ? const Color(0xFF9AA6B6) : Colores.navy2, borderRadius: BorderRadius.circular(99))),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(c.texto, style: const TextStyle(fontSize: 13))),
                Text('${c.peso > 0 ? '+' : ''}${fmt(c.peso)}', style: const TextStyle(color: Colores.tenue, fontSize: 12)),
              ]),
            ),
          const Text('Valores = contribución al logit (similar a SHAP). Pesos ilustrativos, no entrenados.', style: TextStyle(color: Colores.tenue, fontSize: 11.5)),
        ]),
      ),
      Tarjeta(
        titulo: 'Decisión del profesional',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ResumenErrores(_e),
          if (!_modificando)
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colores.verde),
                onPressed: () {
                  s.decidir(p, prior: sug.prioridad, aceptada: true);
                  aviso(context, '${p.id} clasificado como Prioridad ${pr(sug.prioridad).romano}.');
                },
                icon: const Icon(Icons.check),
                label: const Text('Aceptar sugerencia'),
              ),
              OutlinedButton.icon(onPressed: () => setState(() => _modificando = true), icon: const Icon(Icons.edit), label: const Text('Modificar prioridad')),
            ])
          else ...[
            Lista<int>('Nueva prioridad', requerido: true, valor: _nueva, opciones: [1, 2, 3, 4].where((n) => n != sug.prioridad).toList(), texto: (n) => '${pr(n).romano} · ${pr(n).nombre}', error: _e['nueva'], ayuda: 'Debe ser distinta de la sugerida (${pr(sug.prioridad).romano}).', alCambiar: (v) => setState(() {
                  _nueva = v;
                  _bajaOk = false;
                  _e = Map.of(_e)..remove('nueva');
                })),
            Lista<String>('Motivo del cambio', requerido: true, valor: _cat, opciones: kMotivosCambio, texto: (x) => x, error: _e['cat'], alCambiar: (v) => setState(() {
                  _cat = v;
                  _e = Map.of(_e)..remove('cat');
                })),
            Campo(_txt, 'Detalle del motivo', requerido: true, error: _e['txt'], lineas: 2, maxLength: 300, ayuda: 'Entre 15 y 300 caracteres. Alimenta el registro de discrepancias.', alCambiar: (_) => setState(() => _e = Map.of(_e)..remove('txt'))),
            if (_nueva != null && _nueva! > sug.prioridad)
              Aviso(
                TipoAviso.alerta,
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Está asignando una prioridad menos urgente que la sugerida. Esto puede causar sub-triaje.', style: TextStyle(fontWeight: FontWeight.w700)),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _bajaOk,
                    onChanged: (v) => setState(() {
                      _bajaOk = v ?? false;
                      _e = Map.of(_e)..remove('baja');
                    }),
                    title: const Text('Confirmo que reevalué al paciente y asumo la clasificación menos urgente.'),
                    subtitle: _e['baja'] == null ? null : Text(_e['baja']!, style: const TextStyle(color: Colores.rojo)),
                  ),
                ]),
              ),
            Wrap(alignment: WrapAlignment.end, spacing: 10, children: [
              OutlinedButton(onPressed: () => setState(() {
                    _modificando = false;
                    _e = {};
                  }), child: const Text('Cancelar')),
              FilledButton(onPressed: () => _confirmarCambio(s, sug), child: const Text('Confirmar cambio')),
            ]),
          ],
          const SizedBox(height: 6),
          const Text('Cada decisión queda registrada para auditoría con su usuario, hora y versión del modelo.', style: TextStyle(color: Colores.tenue, fontSize: 12)),
        ]),
      ),
    ]);
  }

  Widget _sombra(AppState s) {
    return Tarjeta(
      titulo: 'Decisión profesional (modo sombra)',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Aviso.texto(TipoAviso.info, 'No hay una versión aprobada en producción: la sugerencia del sistema está oculta. Clasifique según su criterio; el sistema guarda ambas para el comité de modelo.'),
        Lista<int>('Prioridad asignada', requerido: true, valor: _nueva, opciones: const [1, 2, 3, 4], texto: (n) => '${pr(n).romano} · ${pr(n).nombre}', error: _e['nueva'], alCambiar: (v) => setState(() {
              _nueva = v;
              _e = {};
            })),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () {
              if (_nueva == null) {
                setState(() => _e = {'nueva': 'Seleccione la prioridad asignada.'});
                return;
              }
              s.decidir(widget.p, prior: _nueva!, aceptada: false);
              aviso(context, '${widget.p.id} clasificado como Prioridad ${pr(_nueva!).romano}.');
            },
            child: const Text('Registrar decisión'),
          ),
        ),
      ]),
    );
  }
}
