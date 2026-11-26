import 'package:flutter/material.dart';
import '../core/datos.dart';
import '../core/validadores.dart';
import '../estado/proveedor.dart';
import 'comunes.dart';

class PaginaGuia extends StatelessWidget {
  const PaginaGuia({super.key});
  @override
  Widget build(BuildContext context) {
    final s = Estado.de(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Encabezado('Guía', 'Cómo probar el prototipo'),
        Tarjeta(
          titulo: 'Usuarios de prueba (ficticios)',
          child: Tabla(['Usuario', 'Contraseña', 'Rol'], [
            for (final u in kUsuarios) [Text(u.usuario, style: const TextStyle(fontFamily: 'monospace')), Text(u.clave, style: const TextStyle(fontFamily: 'monospace')), Text(rolTexto(u.rol))],
          ]),
        ),
        Tarjeta(
          titulo: 'Padrón ficticio (simula RENIEC + historia clínica)',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Tabla(['DNI', 'Dígito', 'Nombre', 'Edad', 'Caso que permite probar'], [
              for (final p in kPadron)
                () {
                  final dv = digitoVerificador(p.dni);
                  final e = edadEn(p.fnac, s.ahora);
                  final caso = p.fallecido
                      ? 'Titular fallecido: debe bloquearse'
                      : !p.seguroActivo
                          ? 'No asegurado: se atiende igual'
                          : e < 18
                              ? 'Menor de edad: exige acompañante'
                              : (p.sexo == 'F' && e <= 55)
                                  ? 'Mujer en edad fértil: pregunta «¿Gestante?»'
                                  : (p.hc != null && p.hc!.diagnosticos.isNotEmpty)
                                      ? 'Antecedentes relevantes'
                                      : 'Sin antecedentes';
                  return <Widget>[Text(p.dni, style: const TextStyle(fontFamily: 'monospace')), Text('${dv.numero} o ${dv.letra}', style: const TextStyle(fontFamily: 'monospace')), Text(p.nombreCompleto), Text('$e'), Text(caso)];
                }(),
            ]),
            const Text('Cualquier otro DNI con dígito correcto (por ejemplo, 42388604-3) se rechaza por no figurar en el padrón. Todos los nombres son inventados.', style: TextStyle(color: Colores.tenue, fontSize: 12.5)),
          ]),
        ),
        const Tarjeta(
          titulo: 'Recorrido sugerido para la exposición',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('1. Enfermera: registre 45872316-3, verifique y clasifique (piloto asistido con v0.2.0).'),
            Text('2. Pruebe errores: 00000000, dígito incorrecto, SpO₂ 101, PAD mayor que PAS, motivo «dolor».'),
            Text('3. Nube: desactive la conexión, registre otro paciente y vuelva a conectar: la cola se sincroniza.'),
            Text('4. Comité: en «Modelo y DevOps» cargue los datos históricos y revise las métricas de v0.3.0.'),
            Text('5. Comité: apruebe v0.3.0 (pedirá justificación si una meta no se cumple) y pásela a producción.'),
            Text('6. Comité: ejecute las autopruebas y lleve v0.4.0 por QA → modo sombra.'),
            Text('7. Médico jefe: tablero, línea base H1, cola A* y revaloraciones con «Avanzar reloj».'),
          ]),
        ),
        const Tarjeta(
          titulo: 'Qué es real y qué es simulado',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KV('Verificación de identidad', 'Dígito verificador real + padrón ficticio (real: servicio autorizado de RENIEC)'),
            KV('Historia clínica', 'Datos ficticios locales (real: historia clínica digital vía HL7 FHIR)'),
            KV('Modelo', 'Logit con pesos ilustrativos + reglas (real: XGBoost + TF-IDF entrenado con datos autorizados)'),
            KV('Nube', 'Cola local con estado enviado/pendiente (real: almacenamiento cifrado, Medallion y MLflow)'),
            KV('Seudonimización', 'HMAC-SHA256 con clave de demostración (real: clave institucional del hospital)'),
            KV('Auditoría', 'Cadena SHA-256 en el dispositivo (real: registro inmutable en servidor)'),
            KV('Almacenamiento', 'Local en el dispositivo (shared_preferences)'),
          ]),
        ),
      ]),
    );
  }
}
