// Pruebas automáticas: ejecute `flutter test` en la carpeta del proyecto.

import 'package:flutter_test/flutter_test.dart';
import 'package:triaje_inteligente/core/algoritmos.dart';
import 'package:triaje_inteligente/core/datos.dart';
import 'package:triaje_inteligente/core/modelo.dart';
import 'package:triaje_inteligente/core/validadores.dart';

void main() {
  group('DNI', () {
    test('rechaza dígitos iguales, secuencias y longitudes incorrectas', () {
      expect(validarDNI('00000000', '6').ok, isFalse);
      expect(validarDNI('11111111', 'A').ok, isFalse);
      expect(validarDNI('12345678', '1').ok, isFalse);
      expect(validarDNI('87654321', '5').ok, isFalse);
      expect(validarDNI('4587231', '3').ok, isFalse);
      expect(validarDNI('458723160', '3').ok, isFalse);
      expect(validarDNI('4587A316', '3').ok, isFalse);
      expect(validarDNI('', '').ok, isFalse);
    });
    test('dígito verificador', () {
      expect(validarDNI('45872316', '').ok, isFalse);
      expect(validarDNI('45872316', '4').ok, isFalse);
      expect(validarDNI('45872316', '3').ok, isTrue);
      expect(validarDNI('45872316', 'h').ok, isTrue);
      final d = digitoVerificador('42388604');
      expect(d.numero, '3');
      expect(d.letra, 'H');
    });
    test('todo el padrón ficticio tiene DNI válido', () {
      for (final p in kPadron) {
        expect(validarDNI(p.dni, digitoVerificador(p.dni).numero).ok, isTrue, reason: p.dni);
      }
    });
  });

  group('Campos de registro', () {
    test('nombres', () {
      expect(validarNombre('Juan2', 'el nombre').ok, isFalse);
      expect(validarNombre('<script>', 'el nombre').ok, isFalse);
      expect(validarNombre('Juan  Pérez', 'el nombre').ok, isFalse);
      expect(validarNombre('Aaana', 'el nombre').ok, isFalse);
      expect(validarNombre("María José O'Neill-Paz", 'el nombre').ok, isTrue);
    });
    test('celular', () {
      expect(validarCelular('987654321').ok, isTrue);
      expect(validarCelular('98765432').ok, isFalse);
      expect(validarCelular('887654321').ok, isFalse);
      expect(validarCelular('999999999').ok, isFalse);
    });
    test('fecha de nacimiento', () {
      final hoy = DateTime(2026, 11, 24);
      expect(validarFechaNac('30/02/2001', hoy).ok, isFalse);
      expect(validarFechaNac('01/01/2027', hoy).ok, isFalse);
      expect(validarFechaNac('01/01/1890', hoy).ok, isFalse);
      expect(validarFechaNac('05/05/1990', hoy).edad, 36);
    });
    test('documentos extranjeros', () {
      expect(validarPasaporte('AAAAAA').ok, isFalse);
      expect(validarPasaporte('AB12345').ok, isTrue);
      expect(validarCE('12345678').ok, isFalse);
      expect(validarCE('001234567').ok, isTrue);
    });
  });

  group('Signos vitales y motivo', () {
    test('rangos imposibles y formato', () {
      expect(validarVital(vitalPorId('spo2'), '101').ok, isFalse);
      expect(validarVital(vitalPorId('temp'), '29,9').ok, isFalse);
      expect(validarVital(vitalPorId('temp'), '36,9').valor, 36.9);
      expect(validarVital(vitalPorId('temp'), '36.95').ok, isFalse);
      expect(validarVital(vitalPorId('fc'), '80.5').ok, isFalse);
      expect(validarVital(vitalPorId('fc'), '1e2').ok, isFalse);
      expect(validarVital(vitalPorId('spo2'), '80').critico, isTrue);
      expect(validarVitalesCruzado({'pas': 90, 'pad': 95}).containsKey('pad'), isTrue);
    });
    test('motivo de consulta', () {
      expect(validarMotivo('dolor').ok, isFalse);
      expect(validarMotivo('<script>alert(1)</script> falta de aire').ok, isFalse);
      expect(validarMotivo('1234567890 12345').ok, isFalse);
      expect(validarMotivo('dolor dolor dolor dolor').ok, isFalse);
      expect(validarMotivo('Falta de aire y silbidos en el pecho desde esta mañana').ok, isTrue);
      expect(filtrarTexto('Rosa trae DNI 45872316 y cel 987654321', ['Rosa']), '[NOMBRE] trae DNI [DOC] y cel [TEL]');
    });
  });

  group('Modelo y reglas de seguridad', () {
    test('vital crítico fuerza Prioridad I', () {
      expect(predecir(const EntradaModelo(edad: 40, vit: {'spo2': 80}, motivo: 'cansancio general')).prioridad, 1);
    });
    test('alarma de dengue: mínimo II', () {
      expect(predecir(const EntradaModelo(edad: 30, vit: {'temp': 38.6}, motivo: 'Fiebre con petequias y dolor abdominal intenso')).prioridad <= 2, isTrue);
    });
    test('caso leve: IV', () {
      expect(predecir(const EntradaModelo(edad: 27, vit: {'pas': 118, 'pad': 76, 'fc': 80, 'fr': 16, 'temp': 37.1, 'spo2': 98, 'glasgow': 15, 'eva': 2}, motivo: 'Dolor de garganta y resfrío')).prioridad, 4);
    });
    test('v0.2.0 no usa el texto; v0.3.0 sí', () {
      const e = EntradaModelo(edad: 50, vit: {'pas': 130, 'pad': 80, 'fc': 90, 'fr': 18, 'temp': 36.8, 'spo2': 97, 'glasgow': 15, 'eva': 3}, motivo: 'dolor en el pecho');
      expect(predecir(e, version: '0.2.0').contribuciones.any((c) => c.fuente == 'texto'), isFalse);
      expect(predecir(e, version: '0.3.0').contribuciones.any((c) => c.fuente == 'texto'), isTrue);
    });
  });

  group('Algoritmos', () {
    test('A* es óptimo y pone primero la Prioridad I', () {
      const ps = [PacienteCola(3, 0), PacienteCola(2, 5), PacienteCola(4, 1), PacienteCola(1, 8), PacienteCola(3, 2)];
      final r = aEstrella(ps, [10, 12]);
      expect(ps[r.orden.first].prior, 1);
      // fuerza bruta con la misma restricción
      var mejor = double.infinity;
      void perm(List<int> pre, List<int> resto) {
        if (resto.isEmpty) {
          if (ps[pre.first].prior == 1) {
            final c = simularOrden(ps, pre, [10, 12]).costo;
            if (c < mejor) mejor = c;
          }
          return;
        }
        for (var i = 0; i < resto.length; i++) {
          perm([...pre, resto[i]], [...resto]..removeAt(i));
        }
      }

      perm([], [0, 1, 2, 3, 4]);
      expect(r.costo, closeTo(mejor, 1e-9));
    });
    test('métricas', () {
      const pares = [Par(1, 1), Par(2, 2), Par(3, 3), Par(4, 4), Par(2, 3)];
      expect(kappa(pares)!, closeTo(0.737, 0.001));
      expect(metricasCriticas(pares).recall!, closeTo(2 / 3, 1e-9));
      expect(auroc([0.9, 0.8, 0.2, 0.1], [true, true, false, false]), 1.0);
    });
    test('SHA-256 estándar', () {
      expect(sha256Hex('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      expect(sha256Hex(''), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    });
  });
}
