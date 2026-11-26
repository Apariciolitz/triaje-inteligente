// A* para ordenar la cola, métricas de evaluación, K-Means + silueta,
// SHA-256 y seudonimización (HMAC simplificado). Sin dependencias externas.

import 'dart:convert';
import 'dart:math' as math;
import 'datos.dart';

/* =================== A* =================== */
class PacienteCola {
  final int prior;
  final double llegada; // minutos relativos a "ahora" (negativo = ya espera)
  const PacienteCola(this.prior, this.llegada);
}

class ResultadoBusqueda {
  final List<int> orden;
  final double costo;
  final int expandidos;
  final String metodo;
  final List<double> inicios;
  const ResultadoBusqueda(this.orden, this.costo, this.expandidos, this.metodo, this.inicios);
}

/// g: espera ponderada por prioridad + 10 × peso × exceso sobre el tiempo de referencia.
double costoPaciente(PacienteCola p, double inicio) {
  final espera = math.max(0.0, inicio - p.llegada);
  final exceso = math.max(0.0, espera - pr(p.prior).limiteMin);
  return kPesoEspera[p.prior]! * espera + 10 * kPesoEspera[p.prior]! * exceso;
}

({double costo, List<double> inicios}) simularOrden(List<PacienteCola> pacs, List<int> orden, List<double> libres) {
  final t = List<double>.from(libres)..sort();
  var costo = 0.0;
  final inicios = <double>[];
  for (final i in orden) {
    final p = pacs[i];
    final ini = math.max(t[0], p.llegada);
    costo += costoPaciente(p, ini);
    inicios.add(ini);
    t[0] = ini + kDuracionAtencion[p.prior]!;
    t.sort();
  }
  return (costo: costo, inicios: inicios);
}

class _Nodo {
  final int mask;
  final List<double> t;
  final double g;
  final double f;
  final List<int> orden;
  _Nodo(this.mask, this.t, this.g, this.f, this.orden);
}

/// Estado = pacientes ya asignados (máscara) + tiempos libres de los tópicos.
/// h(n) = costo de cada pendiente si empezara en el tópico que antes se libera
/// (cota inferior → heurística admisible). Prioridad I siempre primero.
ResultadoBusqueda aEstrella(List<PacienteCola> pacs, List<double> libres, {int maxN = 9}) {
  final n = pacs.length;
  if (n == 0) return const ResultadoBusqueda([], 0, 0, 'A*', []);
  if (n > maxN) {
    final orden = List<int>.generate(n, (i) => i)..sort((a, b) {
        final c = pacs[a].prior.compareTo(pacs[b].prior);
        return c != 0 ? c : pacs[a].llegada.compareTo(pacs[b].llegada);
      });
    final s = simularOrden(pacs, orden, libres);
    return ResultadoBusqueda(orden, s.costo, 0, 'voraz (cola > $maxN)', s.inicios);
  }
  final full = (1 << n) - 1;
  double h(int mask, List<double> t) {
    var s = 0.0;
    for (var i = 0; i < n; i++) {
      if (mask & (1 << i) == 0) s += costoPaciente(pacs[i], math.max(t[0], pacs[i].llegada));
    }
    return s;
  }

  bool quedaI(int mask) {
    for (var i = 0; i < n; i++) {
      if (mask & (1 << i) == 0 && pacs[i].prior == 1) return true;
    }
    return false;
  }

  final t0 = List<double>.from(libres)..sort();
  final abiertos = <_Nodo>[_Nodo(0, t0, 0, h(0, t0), [])];
  final visto = <String, double>{};
  var exp = 0;
  while (abiertos.isNotEmpty) {
    var bi = 0;
    for (var k = 1; k < abiertos.length; k++) {
      if (abiertos[k].f < abiertos[bi].f) bi = k;
    }
    final nodo = abiertos.removeAt(bi);
    if (nodo.mask == full) {
      final s = simularOrden(pacs, nodo.orden, libres);
      return ResultadoBusqueda(nodo.orden, nodo.g, exp, 'A*', s.inicios);
    }
    final clave = '${nodo.mask}|${nodo.t.join(',')}';
    final prev = visto[clave];
    if (prev != null && prev <= nodo.g) continue;
    visto[clave] = nodo.g;
    exp++;
    final soloI = quedaI(nodo.mask);
    for (var i = 0; i < n; i++) {
      if (nodo.mask & (1 << i) != 0) continue;
      if (soloI && pacs[i].prior != 1) continue;
      final ini = math.max(nodo.t[0], pacs[i].llegada);
      final t2 = List<double>.from(nodo.t);
      t2[0] = ini + kDuracionAtencion[pacs[i].prior]!;
      t2.sort();
      final g2 = nodo.g + costoPaciente(pacs[i], ini);
      final m2 = nodo.mask | (1 << i);
      abiertos.add(_Nodo(m2, t2, g2, g2 + h(m2, t2), [...nodo.orden, i]));
    }
  }
  return const ResultadoBusqueda([], double.infinity, 0, 'A*', []);
}

/* =================== Métricas =================== */
class Par {
  final int ref; // decisión profesional
  final int pred; // sugerencia del modelo
  const Par(this.ref, this.pred);
}

List<List<int>> matrizConfusion(List<Par> pares) {
  final m = List.generate(4, (_) => List<int>.filled(4, 0));
  for (final p in pares) {
    m[p.ref - 1][p.pred - 1]++;
  }
  return m;
}

double? kappa(List<Par> pares) {
  final n = pares.length;
  if (n < 2) return null;
  final m = matrizConfusion(pares);
  var po = 0.0;
  for (var i = 0; i < 4; i++) {
    po += m[i][i];
  }
  po /= n;
  var pe = 0.0;
  for (var i = 0; i < 4; i++) {
    final r = m[i].reduce((a, b) => a + b);
    var c = 0;
    for (var k = 0; k < 4; k++) {
      c += m[k][i];
    }
    pe += (r / n) * (c / n);
  }
  if (pe == 1) return po == 1 ? 1.0 : 0.0;
  return (po - pe) / (1 - pe);
}

/// Positivo = prioridad I o II.
({double? recall, double? precision, int vp, int fp, int fn}) metricasCriticas(List<Par> pares) {
  var vp = 0, fp = 0, fn = 0;
  for (final x in pares) {
    final r = x.ref <= 2, p = x.pred <= 2;
    if (r && p) {
      vp++;
    } else if (!r && p) {
      fp++;
    } else if (r && !p) {
      fn++;
    }
  }
  return (recall: vp + fn > 0 ? vp / (vp + fn) : null, precision: vp + fp > 0 ? vp / (vp + fp) : null, vp: vp, fp: fp, fn: fn);
}

double? f1Macro(List<Par> pares) {
  final m = matrizConfusion(pares);
  final f = <double>[];
  for (var k = 0; k < 4; k++) {
    final vp = m[k][k];
    final fn = m[k].reduce((a, b) => a + b) - vp;
    var col = 0;
    for (var i = 0; i < 4; i++) {
      col += m[i][k];
    }
    final fp = col - vp;
    if (vp + fn == 0 && vp + fp == 0) continue;
    final p = vp + fp > 0 ? vp / (vp + fp) : 0.0;
    final r = vp + fn > 0 ? vp / (vp + fn) : 0.0;
    f.add(p + r > 0 ? 2 * p * r / (p + r) : 0.0);
  }
  if (f.isEmpty) return null;
  return f.reduce((a, b) => a + b) / f.length;
}

/// AUROC por Mann–Whitney.
double? auroc(List<double> puntajes, List<bool> positivos) {
  final pos = <double>[], neg = <double>[];
  for (var i = 0; i < puntajes.length; i++) {
    (positivos[i] ? pos : neg).add(puntajes[i]);
  }
  if (pos.isEmpty || neg.isEmpty) return null;
  var s = 0.0;
  for (final a in pos) {
    for (final b in neg) {
      s += a > b ? 1 : (a == b ? 0.5 : 0);
    }
  }
  return s / (pos.length * neg.length);
}

/* =================== K-Means + silueta =================== */
double _d2(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += (a[i] - b[i]) * (a[i] - b[i]);
  }
  return s;
}

List<int>? kmeans(List<List<double>> x, int k, {int iter = 50}) {
  final n = x.length;
  if (n < k + 1) return null;
  final cent = <List<double>>[List<double>.from(x[0])];
  while (cent.length < k) {
    var bi = 0;
    var bd = -1.0;
    for (var i = 0; i < n; i++) {
      final d = cent.map((c) => _d2(x[i], c)).reduce(math.min);
      if (d > bd) {
        bd = d;
        bi = i;
      }
    }
    cent.add(List<double>.from(x[bi]));
  }
  var lab = List<int>.filled(n, 0);
  for (var it = 0; it < iter; it++) {
    final nl = List<int>.generate(n, (i) {
      var bi = 0;
      var bd = double.infinity;
      for (var j = 0; j < k; j++) {
        final d = _d2(x[i], cent[j]);
        if (d < bd) {
          bd = d;
          bi = j;
        }
      }
      return bi;
    });
    var cambio = false;
    for (var i = 0; i < n; i++) {
      if (nl[i] != lab[i]) cambio = true;
    }
    lab = nl;
    for (var j = 0; j < k; j++) {
      final miembros = <List<double>>[];
      for (var i = 0; i < n; i++) {
        if (lab[i] == j) miembros.add(x[i]);
      }
      if (miembros.isEmpty) continue;
      cent[j] = List<double>.generate(x[0].length, (d) => miembros.fold<double>(0, (s, m) => s + m[d]) / miembros.length);
    }
    if (!cambio && it > 0) break;
  }
  return lab;
}

double? silueta(List<List<double>> x, List<int> lab) {
  final grupos = lab.toSet();
  if (grupos.length < 2) return null;
  double d(List<double> a, List<double> b) => math.sqrt(_d2(a, b));
  var tot = 0.0;
  for (var i = 0; i < x.length; i++) {
    final mismos = <List<double>>[];
    for (var j = 0; j < x.length; j++) {
      if (j != i && lab[j] == lab[i]) mismos.add(x[j]);
    }
    if (mismos.isEmpty) continue;
    final a = mismos.fold<double>(0, (s, m) => s + d(x[i], m)) / mismos.length;
    var b = double.infinity;
    for (final g in grupos) {
      if (g == lab[i]) continue;
      final otros = <List<double>>[];
      for (var j = 0; j < x.length; j++) {
        if (lab[j] == g) otros.add(x[j]);
      }
      b = math.min(b, otros.fold<double>(0, (s, m) => s + d(x[i], m)) / otros.length);
    }
    tot += (b - a) / math.max(a, b);
  }
  return tot / x.length;
}

/* =================== SHA-256 =================== */
const List<int> _k = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];
const int _m32 = 0xFFFFFFFF;
int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _m32;

String sha256Hex(String texto) {
  final bytes = <int>[...utf8.encode(texto)];
  final bitLen = bytes.length * 8;
  bytes.add(0x80);
  while (bytes.length % 64 != 56) {
    bytes.add(0);
  }
  // longitud en 64 bits (los 4 bytes altos son 0 para mensajes < 512 MB)
  bytes.addAll([0, 0, 0, 0, (bitLen >> 24) & 0xff, (bitLen >> 16) & 0xff, (bitLen >> 8) & 0xff, bitLen & 0xff]);
  final h = <int>[0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
  final w = List<int>.filled(64, 0);
  for (var o = 0; o < bytes.length; o += 64) {
    for (var i = 0; i < 16; i++) {
      w[i] = ((bytes[o + 4 * i] << 24) | (bytes[o + 4 * i + 1] << 16) | (bytes[o + 4 * i + 2] << 8) | bytes[o + 4 * i + 3]) & _m32;
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & _m32;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e & _m32) & g);
      final t1 = (hh + s1 + ch + _k[i] + w[i]) & _m32;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & _m32;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & _m32;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _m32;
    }
    h[0] = (h[0] + a) & _m32;
    h[1] = (h[1] + b) & _m32;
    h[2] = (h[2] + c) & _m32;
    h[3] = (h[3] + d) & _m32;
    h[4] = (h[4] + e) & _m32;
    h[5] = (h[5] + f) & _m32;
    h[6] = (h[6] + g) & _m32;
    h[7] = (h[7] + hh) & _m32;
  }
  return h.map((x) => x.toRadixString(16).padLeft(8, '0')).join();
}

const String kClaveDemo = 'clave-institucional-DEMO-no-usar-en-produccion';
String hmacDemo(String clave, String msg) => sha256Hex('$clave:${sha256Hex('$clave|$msg')}');
String seudonimo(String tipo, String numero) => 'P-${hmacDemo(kClaveDemo, '$tipo:$numero').substring(0, 10).toUpperCase()}';
