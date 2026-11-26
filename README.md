# Triaje Inteligente · APF3

Prototipo académico de **triaje asistido por inteligencia artificial** para el Servicio de Emergencia, desarrollado para el curso *Innovación y Transformación Digital*.

> **Datos ficticios.** El padrón simula RENIEC y la historia clínica; el modelo usa pesos ilustrativos (no entrenados). **La decisión final siempre es del profesional de salud.**

## Qué incluye

- **Registro con validación estricta:** DNI con dígito verificador (rechaza `00000000`, secuencias y números inventados), carné de extranjería, pasaporte y pacientes sin documento (NN).
- **Evaluación del paciente:** historia clínica automática, motivo de consulta con PLN, 8 signos vitales con rangos imposibles y valores críticos.
- **Sugerencia explicable:** reglas de seguridad clínica + modelo de riesgo, con los motivos de cada sugerencia.
- **Ciclo DevOps del modelo:** Desarrollo → QA → Modo sombra → Aprobada → Producción. Solo el comité de modelo cambia estados; ninguna versión llega directamente a producción.
- **Modelo híbrido (local + nube):** el triaje funciona sin internet; la nube recibe solo datos seudonimizados mediante una cola de sincronización.
- **Tablero de la jefatura:** indicadores H1–H4, cola ordenada con búsqueda A* y tópicos.
- **Métricas del comité:** matriz de confusión, recall, precision, F1, AUROC, kappa, deriva de datos y K-Means con silueta.
- **Auditoría:** eventos encadenados con SHA-256, verificables.

## Cómo ejecutarlo

Requisitos: Flutter instalado. En **Windows**, activa *Configuración → Sistema → Avanzado → Modo para desarrolladores*. Ubica el proyecto **fuera de OneDrive** (por ejemplo, `C:\Proyectos`).

```bash
git clone https://github.com/Apariciolitz/triaje-inteligente.git
cd triaje-inteligente

# Genera las carpetas de Android, Web y Windows
flutter create --org pe.edu.utp --project-name triaje_inteligente --platforms=android,web,windows .

flutter pub get
flutter test            # debe terminar en "All tests passed!"
flutter run -d chrome   # o `flutter run` con un emulador o celular
```

APK para Android: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.

## Usuarios de prueba (ficticios)

| Usuario | Contraseña | Rol |
|---|---|---|
| `enfermera1` | `Triaje2026!` | Enfermera de triaje |
| `medico.jefe` | `Jefe2026!` | Médico jefe de emergencia |
| `comite` | `Comite2026!` | Comité de modelo |

DNIs de prueba: ver la sección **Guía** dentro de la app (por ejemplo, `45872316` con dígito `3`).

## Estructura

```
lib/
  main.dart                arranque y tema (colores del PPT)
  core/datos.dart          prioridades (NTS 042), signos vitales, padrón ficticio, usuarios
  core/validadores.dart    reglas de validación de todos los campos
  core/modelo.dart         modelo de demostración (v0.2.0, v0.3.0, v0.4.0), PLN y reglas de seguridad
  core/algoritmos.dart     A*, métricas, K-Means, silueta, SHA-256
  estado/                  entidades, estado de la app y persistencia local
  ui/                      pantallas
test/                      pruebas automáticas
prototipo-html/            versión web previa en un solo archivo (abrir index.html)
```

## Problemas frecuentes

| Mensaje | Solución |
|---|---|
| `Building with plugins requires symlink support` | Activar el Modo para desarrolladores de Windows |
| `Waiting for another flutter command to release the startup lock` | Esperar a que VS Code termine, o cerrarlo y volver a abrir |
| Aparece «Flutter Demo Home Page» | Se ejecutó en otra carpeta: la terminal debe estar en la carpeta que contiene `pubspec.yaml` |
| «El proceso no puede obtener acceso al archivo» | Mover el proyecto fuera de OneDrive |
