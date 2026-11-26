// Datos de referencia: prioridades (NTS 042-MINSA), signos vitales, padrón
// ficticio (simula RENIEC + historia clínica) y usuarios de demostración.
// TODOS LOS DATOS PERSONALES SON INVENTADOS.

import 'package:flutter/material.dart';

class Prioridad {
  final int nivel;
  final String romano;
  final String nombre;
  final String corto;
  final int limiteMin; // tiempo de referencia hasta la atención
  final Color color;
  final String paraPaciente;
  const Prioridad(this.nivel, this.romano, this.nombre, this.corto, this.limiteMin, this.color, this.paraPaciente);
}

const Map<int, Prioridad> kPrioridades = {
  1: Prioridad(1, 'I', 'Emergencia · atención inmediata', 'Atención inmediata', 0, Color(0xFFC62828),
      'Su vida puede estar en riesgo. Lo atienden de inmediato.'),
  2: Prioridad(2, 'II', 'Urgencia mayor', 'Urgencia mayor', 10, Color(0xFFE65100),
      'Su caso necesita atención pronta. Será atendido antes que las personas con casos menos graves.'),
  3: Prioridad(3, 'III', 'Urgencia menor', 'Urgencia menor', 20, Color(0xFFF9A825),
      'Su caso necesita evaluación médica, pero no hay riesgo inmediato para su vida. Primero se atiende a los casos más graves.'),
  4: Prioridad(4, 'IV', 'Atención no urgente', 'No urgente', 60, Color(0xFF2E7D32),
      'Su caso es de menor gravedad. Será atendido después de los casos urgentes o podrá ser derivado según evaluación médica.'),
};

Prioridad pr(int n) => kPrioridades[n]!;

const Map<int, int> kDuracionAtencion = {1: 30, 2: 20, 3: 15, 4: 10}; // min (parámetros de demostración)
const Map<int, int> kPesoEspera = {1: 8, 2: 4, 3: 2, 4: 1};

class VitalDef {
  final String id;
  final String nombre;
  final String corto;
  final String unidad;
  final double min;
  final double max;
  final int decimales;
  final bool Function(double v) critico;
  final bool Function(double v) alerta;
  const VitalDef(this.id, this.nombre, this.corto, this.unidad, this.min, this.max, this.decimales, this.critico, this.alerta);
}

bool _nunca(double v) => false;

final List<VitalDef> kVitales = [
  VitalDef('pas', 'Presión sistólica', 'PAS', 'mmHg', 40, 300, 0, (v) => v < 80 || v >= 220, (v) => (v >= 80 && v < 90) || (v >= 180 && v < 220)),
  VitalDef('pad', 'Presión diastólica', 'PAD', 'mmHg', 20, 200, 0, (v) => v >= 130, (v) => v >= 110 && v < 130),
  VitalDef('fc', 'Frecuencia cardiaca', 'FC', 'lpm', 20, 250, 0, (v) => v < 40 || v > 150, (v) => (v >= 40 && v < 50) || (v > 120 && v <= 150)),
  VitalDef('fr', 'Frecuencia respiratoria', 'FR', 'rpm', 4, 70, 0, (v) => v < 8 || v > 35, (v) => v >= 25 && v <= 35),
  VitalDef('temp', 'Temperatura', 'T°', '°C', 30, 45, 1, (v) => v < 34 || v >= 41, (v) => v >= 39.5 && v < 41),
  VitalDef('spo2', 'Saturación de oxígeno', 'SpO₂', '%', 40, 100, 0, (v) => v < 85, (v) => v >= 85 && v <= 91),
  VitalDef('glasgow', 'Escala de Glasgow', 'Glasgow', 'pts', 3, 15, 0, (v) => v <= 8, (v) => v >= 9 && v <= 13),
  VitalDef('eva', 'Dolor (EVA)', 'EVA', '/10', 0, 10, 0, _nunca, (v) => v >= 8),
];

VitalDef vitalPorId(String id) => kVitales.firstWhere((d) => d.id == id);

const List<String> kMotivosNoMedido = [
  'Paciente inestable: se priorizó la atención inmediata',
  'Paciente no colabora',
  'Equipo no disponible o averiado',
  'No aplica por condición del paciente',
];

const List<String> kFormasLlegada = [
  'Por sus propios medios',
  'Traído por familiar o acompañante',
  'Ambulancia',
  'Policía o bomberos',
  'Referido de otro establecimiento',
];

const List<String> kParentescos = ['Madre', 'Padre', 'Hijo(a)', 'Cónyuge o pareja', 'Hermano(a)', 'Otro familiar', 'Tutor legal', 'No familiar'];
const List<String> kNacionalidades = ['Venezolana', 'Colombiana', 'Ecuatoriana', 'Chilena', 'Boliviana', 'Argentina', 'Otra'];
const List<String> kMotivosCambio = [
  'Criterio clínico adicional',
  'Dato no registrado en el sistema',
  'Error en signos vitales registrados',
  'Evolución del paciente durante el triaje',
  'Otro',
];
const List<String> kDesenlaces = [
  'Alta',
  'Hospitalización',
  'Ingreso a UCI',
  'Cirugía de emergencia',
  'Fallecimiento',
  'Referido a otro establecimiento',
  'Retiro voluntario',
];
const Set<String> kDesenlacesCriticos = {'Ingreso a UCI', 'Cirugía de emergencia', 'Fallecimiento'};

enum TipoDoc { dni, ce, pasaporte, nn }

String tipoDocTexto(TipoDoc t) => switch (t) {
      TipoDoc.dni => 'DNI',
      TipoDoc.ce => 'Carné de extranjería',
      TipoDoc.pasaporte => 'Pasaporte',
      TipoDoc.nn => 'Sin documento (paciente no identificado)',
    };

class Diagnostico {
  final String cod;
  final String nombre;
  final bool relevante;
  const Diagnostico(this.cod, this.nombre, this.relevante);
  Map<String, dynamic> toJson() => {'cod': cod, 'nombre': nombre, 'relevante': relevante};
  factory Diagnostico.fromJson(Map<String, dynamic> j) => Diagnostico(j['cod'] as String, j['nombre'] as String, j['relevante'] as bool);
}

class HistoriaClinica {
  final List<String> alergias;
  final List<String> medicacion;
  final List<Diagnostico> diagnosticos;
  final int hospAnio;
  final int? ultEmergDias;
  final String? ultEmergMotivo;
  const HistoriaClinica({this.alergias = const [], this.medicacion = const [], this.diagnosticos = const [], this.hospAnio = 0, this.ultEmergDias, this.ultEmergMotivo});

  Map<String, dynamic> toJson() => {
        'alergias': alergias,
        'medicacion': medicacion,
        'diagnosticos': diagnosticos.map((d) => d.toJson()).toList(),
        'hospAnio': hospAnio,
        'ultEmergDias': ultEmergDias,
        'ultEmergMotivo': ultEmergMotivo,
      };
  factory HistoriaClinica.fromJson(Map<String, dynamic> j) => HistoriaClinica(
        alergias: List<String>.from(j['alergias'] as List),
        medicacion: List<String>.from(j['medicacion'] as List),
        diagnosticos: (j['diagnosticos'] as List).map((e) => Diagnostico.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        hospAnio: (j['hospAnio'] as num).toInt(),
        ultEmergDias: (j['ultEmergDias'] as num?)?.toInt(),
        ultEmergMotivo: j['ultEmergMotivo'] as String?,
      );
}

class PersonaPadron {
  final String dni;
  final String nombres;
  final String ap1;
  final String ap2;
  final String sexo;
  final DateTime fnac;
  final bool seguroActivo;
  final bool fallecido;
  final HistoriaClinica? hc;
  const PersonaPadron(this.dni, this.nombres, this.ap1, this.ap2, this.sexo, this.fnac, this.seguroActivo, {this.fallecido = false, this.hc});
  String get nombreCompleto => '$nombres $ap1 $ap2';
}

final List<PersonaPadron> kPadron = [
  PersonaPadron('45872316', 'Rosa Elvira', 'Chumacero', 'Querevalú', 'F', DateTime(1958, 3, 14), true,
      hc: const HistoriaClinica(alergias: ['Ácido acetilsalicílico'], medicacion: ['Salbutamol inhalado', 'Enalapril 10 mg'], diagnosticos: [Diagnostico('J45', 'Asma', true), Diagnostico('I10', 'Hipertensión arterial', true)], hospAnio: 1, ultEmergDias: 12, ultEmergMotivo: 'crisis asmática')),
  PersonaPadron('70345128', 'Luis Alberto', 'Zapata', 'Ramos', 'M', DateTime(1999, 7, 2), true, hc: const HistoriaClinica()),
  PersonaPadron('41239870', 'Carmen Julia', 'Sosa', 'Vílchez', 'F', DateTime(1990, 11, 20), true,
      hc: const HistoriaClinica(alergias: ['Penicilina'], diagnosticos: [Diagnostico('K29', 'Gastritis', false)], ultEmergDias: 210, ultEmergMotivo: 'dolor abdominal')),
  PersonaPadron('08765431', 'Jorge Manuel', 'Ipanaqué', 'Silva', 'M', DateTime(1946, 1, 30), true,
      hc: const HistoriaClinica(medicacion: ['Metformina 850 mg', 'Furosemida 40 mg'], diagnosticos: [Diagnostico('I50', 'Insuficiencia cardiaca', true), Diagnostico('E11', 'Diabetes tipo 2', true), Diagnostico('N18', 'Enfermedad renal crónica', true)], hospAnio: 2, ultEmergDias: 45, ultEmergMotivo: 'descompensación cardiaca')),
  PersonaPadron('76019284', 'Valeria Nicole', 'Castillo', 'Merino', 'F', DateTime(2011, 5, 9), true,
      hc: const HistoriaClinica(medicacion: ['Salbutamol inhalado'], diagnosticos: [Diagnostico('J45', 'Asma', true)], ultEmergDias: 95, ultEmergMotivo: 'crisis asmática leve')),
  PersonaPadron('47561209', 'Pedro Pablo', 'Yarlequé', 'Coveñas', 'M', DateTime(1975, 9, 15), false),
  PersonaPadron('02948173', 'Teresa de Jesús', 'Morales', 'Lama', 'F', DateTime(1938, 12, 1), true, fallecido: true),
  PersonaPadron('72830461', 'Diego Armando', 'Ruiz', 'Céspedes', 'M', DateTime(2003, 2, 28), true,
      hc: const HistoriaClinica(alergias: ['Fenitoína'], medicacion: ['Levetiracetam 500 mg'], diagnosticos: [Diagnostico('G40', 'Epilepsia', true)], hospAnio: 1, ultEmergDias: 20, ultEmergMotivo: 'crisis convulsiva')),
  PersonaPadron('43176502', 'Lucía Fernanda', 'Nole', 'Prieto', 'F', DateTime(1985, 6, 18), true, hc: const HistoriaClinica()),
  PersonaPadron('61034927', 'Mateo Sebastián', 'Correa', 'Atoche', 'M', DateTime(2024, 8, 10), true, hc: const HistoriaClinica()),
];

PersonaPadron? buscarPadron(String dni) {
  for (final p in kPadron) {
    if (p.dni == dni) return p;
  }
  return null;
}

enum Rol { enfermera, jefe, comite }

String rolTexto(Rol r) => switch (r) {
      Rol.enfermera => 'Enfermera de triaje',
      Rol.jefe => 'Médico jefe de emergencia',
      Rol.comite => 'Comité de modelo',
    };

class Usuario {
  final String usuario;
  final String clave;
  final String nombre;
  final Rol rol;
  const Usuario(this.usuario, this.clave, this.nombre, this.rol);
}

const List<Usuario> kUsuarios = [
  Usuario('enfermera1', 'Triaje2026!', 'Lic. Ana Torres (ficticio)', Rol.enfermera),
  Usuario('medico.jefe', 'Jefe2026!', 'Dr. Carlos Paz (ficticio)', Rol.jefe),
  Usuario('comite', 'Comite2026!', 'Comité de modelo (ficticio)', Rol.comite),
];

int edadEn(DateTime fnac, DateTime ahora) {
  var e = ahora.year - fnac.year;
  if (ahora.month < fnac.month || (ahora.month == fnac.month && ahora.day < fnac.day)) e--;
  return e;
}
