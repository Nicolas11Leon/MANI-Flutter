# MANI — Cliente Flutter (Web & Mobile)

<p align="center">
  <img src="https://raw.githubusercontent.com/Trama-AS/.github/main/assets/mani-logo.png" alt="MANI Logo" width="180" onerror="this.style.display='none'"/>
</p>

<p align="center">
  <strong>Plataforma Multi-Tenant de Formalización de Operaciones de Servicio</strong><br>
  <em>Desarrollado por TRAMA · Ingeniería de Software</em>
</p>

<p align="center">
  <a href="https://github.com/Trama-AS/MANI-Flutter/actions/workflows/ci.yml">
    <img src="https://github.com/Trama-AS/MANI-Flutter/actions/workflows/ci.yml/badge.svg" alt="CI Status" />
  </a>
  <a href="https://github.com/Trama-AS/MANI-Flutter/pkgs/container/mani-flutter">
    <img src="https://img.shields.io/badge/GHCR-Docker%20Image-blue?logo=docker" alt="Docker GHCR" />
  </a>
  <a href="https://flutter.dev">
    <img src="https://img.shields.io/badge/Flutter-3.x%20%7C%20Dart-02569B?logo=flutter&logoColor=white" alt="Flutter Version" />
  </a>
  <a href="https://sonarcloud.io/project/overview?id=Trama-AS_MANI-Flutter">
    <img src="https://sonarcloud.io/api/project_badges/measure?project=Trama-AS_MANI-Flutter&metric=alert_status" alt="Quality Gate Status" />
  </a>
</p>

---

## 📌 Acerca de MANI

**MANI** es una plataforma de software multi-tenant diseñada para formalizar digitalmente las operaciones de empresas de servicios. Permite conectar a **Clientes** con **Aliados** (prestadores de servicio) a través de un ciclo de vida operativo integral:

$$\text{Solicitud} \longrightarrow \text{Cotización} \longrightarrow \text{Ejecución} \longrightarrow \text{Calificación} \longrightarrow \text{Cierre}$$

Este repositorio (`MANI-Flutter`) aloja el frontend multiplataforma del ecosistema, ofreciendo una experiencia responsiva tanto en Web como en dispositivos móviles.

---

## 🚀 Características Principales

- **Arquitectura Multi-Tenant:** Aislamiento lógico por empresa/tenant con personalización de catálogos y cobertura.
- **Gestión de Actores:** Roles diferenciados para Clientes, Aliados y Administradores de Tenant.
- **Ciclo del Servicio en Tiempo Real:** Seguimiento paso a paso del estado de la prestación del servicio.
- **Contenerización Nativa:** Despliegue de producción Web optimizado mediante Docker y Nginx SPA.
- **Calidad y DevSecOps Integrado:** Validaciones de linter, pruebas automatizadas con cobertura LCOV y análisis estático con SonarCloud.

---

## 🛠️ Stack Tecnológico

| Capa | Tecnología |
| :--- | :--- |
| **Lenguaje & Framework** | [Flutter](https://flutter.dev/) (Channel Stable) & [Dart](https://dart.dev/) (^3.9.2) |
| **Diseño / UI** | Material Design 3 |
| **Servidor Web (Prod)** | [Nginx](https://nginx.org/) (Alpine Linux) |
| **Contenedorización** | [Docker](https://www.docker.com/) & Docker Buildx |
| **Registro de Imágenes** | [GitHub Container Registry (GHCR)](https://ghcr.io) |
| **CI / CD** | GitHub Actions |
| **SAST & Calidad** | SonarCloud & Dart Analyze |

---

## ⚙️ Configuración y Ejecución Local

### Prerrequisitos
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.9.2`)
- [Dart SDK](https://dart.dev/get-dart)
- [Docker](https://docs.docker.com/get-docker/) (opcional, para empaquetado web)

### 1. Clonar el repositorio
```bash
git clone https://github.com/Trama-AS/MANI-Flutter.git
cd MANI-Flutter
```

### 2. Configurar variables de entorno
Copia el archivo de ejemplo para definir las variables requeridas:
```bash
cp .env.example .env
```

### 3. Instalar dependencias
```bash
flutter pub get
```

### 4. Ejecutar la aplicación
* **Web (Chrome):**
  ```bash
  flutter run -d chrome
  ```
* **Móvil / Emulador:**
  ```bash
  flutter run
  ```

---

## 🧪 Pruebas y Análisis de Calidad

Para validar el código antes de realizar commits o pull requests:

```bash
# 1. Comprobar formato de código
dart format --output=show --set-exit-if-changed .

# 2. Análisis estático (Linter)
flutter analyze

# 3. Pruebas unitarias y de widgets con cobertura
flutter test --coverage
```

---

## 🐳 Contenedorización con Docker

El proyecto cuenta con un `Dockerfile` multi-stage optimizado para compilar la aplicación Flutter Web y servirla mediante Nginx:

```bash
# Construir la imagen localmente
docker build -t mani-flutter:local .

# Ejecutar el contenedor en el puerto 8080
docker run -d -p 8080:80 --name mani-web mani-flutter:local
```
Accede desde el navegador en `http://localhost:8080`.

---

## 🌿 Flujo de Trabajo y CI/CD (Gitflow)

El proyecto sigue la estrategia de ramas y promoción de ambientes definida en el **ADR-0004**:

$$\text{develop (Development)} \longrightarrow \text{release (Testing / QA)} \longrightarrow \text{main (Production)}$$

| Rama | Propósito | Pipeline / Workflows | Artefacto Generado |
| :--- | :--- | :--- | :--- |
| **`develop`** | Integración continua de features | Formato, Linter, Tests con Cobertura, Build Web Check | Imagen Docker `ghcr.io/trama-as/mani-flutter:dev` |
| **`release`** | Estabilización y pruebas de QA | Formato, Linter, Tests con Cobertura, Build Web Check | Imagen Docker `ghcr.io/trama-as/mani-flutter:staging` y artefacto `flutter-web-staging.zip` |
| **`main`** | Producción oficial | Formato, Linter, Tests, SonarCloud SAST & Quality Gate | Imagen Docker `ghcr.io/trama-as/mani-flutter:latest` y GitHub Release con tag `vX.Y.Z` |

### Convención de Commits
Se exige el estándar de **Conventional Commits** en inglés:
* `feat:` Nueva funcionalidad.
* `fix:` Corrección de errores.
* `docs:` Cambios en documentación.
* `style:` Formato, punto y coma faltantes, etc. (sin cambios en lógica).
* `refactor:` Refactorización de código en producción.
* `test:` Adición o refactorización de tests.
* `ci:` Cambios en configuración de integración continua y pipelines.

---

## 👥 Equipo y Autoría

Desarrollado por el equipo de ingeniería de **TRAMA**:
- **Organización:** [TRAMA · Ingeniería de Software](https://github.com/Trama-AS)
- **Repositorio:** [MANI-Flutter](https://github.com/Trama-AS/MANI-Flutter)

---

## 📄 Licencia

Este proyecto es propiedad de **TRAMA** y se rige bajo los términos y condiciones del proyecto MANI.
