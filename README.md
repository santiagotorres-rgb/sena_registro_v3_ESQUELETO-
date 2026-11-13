# Sena Registro v2 — Reestructurado en MVC

## ¿Qué es MVC?

**MVC (Modelo–Vista–Controlador)** es un patrón de arquitectura de software que
separa una aplicación en tres capas con responsabilidades distintas:

| Capa | Pregunta que responde | Qué contiene en este proyecto |
|---|---|---|
| **Modelo** (`models/`) | "¿Cómo se guardan/leen los datos?" | `AprendizModel.php`: todo el SQL (SELECT, INSERT, UPDATE, DELETE) sobre la tabla `aprendices`. |
| **Vista** (`views/`) | "¿Qué ve el usuario?" | Los `.php` con HTML puro que muestran el listado y los formularios. No tienen SQL. |
| **Controlador** (`controllers/`) | "¿Qué debe pasar cuando el usuario hace clic o envía un formulario?" | `AprendizController.php`: recibe la petición, le pide datos/acciones al Modelo, y elige qué Vista mostrar. |

Adicionalmente se agregó `public/index.php`, un **Front Controller** (controlador
frontal): es la única puerta de entrada de la aplicación. Todas las peticiones
llegan primero ahí y ese archivo decide, según `?accion=...`, qué método del
Controlador ejecutar.

## ¿Por qué se utiliza MVC?

- **Separación de responsabilidades**: si hay un error en una consulta SQL, se
  sabe que está en `models/`; si hay un error visual, está en `views/`. Antes,
  el HTML, el SQL y la lógica estaban mezclados en el mismo archivo (por
  ejemplo `listar.php` tenía SQL y HTML juntos).
- **Mantenibilidad**: cambiar el diseño (Vista) no obliga a tocar el SQL
  (Modelo), y viceversa.
- **Reutilización**: `AprendizModel` puede ser usado por otros controladores
  en el futuro (por ejemplo, una API) sin repetir el código de acceso a datos.
- **Escalabilidad**: agregar una nueva entidad (por ejemplo "Instructores")
  solo implica crear su propio Modelo, Vista y Controlador siguiendo el mismo
  patrón, sin desordenar lo que ya existe.
- **Facilidad para trabajar en equipo**: una persona puede enfocarse en el
  diseño (Vistas) mientras otra trabaja en la lógica de datos (Modelos), sin
  pisarse el trabajo.
- **Es el estándar de la industria**: frameworks como Laravel, Symfony,
  Spring MVC, Django y Ruby on Rails están construidos sobre este mismo patrón,
  así que aprenderlo aquí prepara al aprendiz para herramientas profesionales.

## Estructura de carpetas

```
sena_registro_v2/
├── config/
│   ├── Database.php               # Conexión PDO a MySQL
│   ├── Auth.php                   # Sesión, roles y "guardias de ruta" (login requerido / rol requerido)
│   └── Correo.php                 # Envío de correos de recuperación (mail() + log de respaldo)
├── models/
│   ├── AprendizModel.php          # SQL: obtenerTodos, obtenerRecientes, contarTotal, crear, actualizar, eliminar
│   └── UsuarioModel.php           # SQL: login, roles, tokens de recuperación de contraseña
├── controllers/
│   ├── AprendizController.php     # Orquesta Modelo <-> Vista, protegido por rol
│   ├── AuthController.php         # Login, recuperación de contraseña y logout
│   └── DashboardController.php    # Reparte a la vista de dashboard según el rol
├── views/
│   ├── aprendices/
│   │   ├── listar.php             # Botones visibles según el rol
│   │   ├── formulario_crear.php
│   │   └── formulario_editar.php
│   ├── dashboard/
│   │   ├── coordinador.php        # Estadísticas generales del sistema
│   │   ├── docente.php            # Total de aprendices + accesos rápidos
│   │   └── aprendiz.php           # Solo su propia información
│   ├── auth/
│   │   ├── login.php              # Formulario de login (+ enlace "olvidé mi contraseña")
│   │   ├── recuperar.php          # Paso 1: pedir el correo
│   │   └── restablecer.php        # Paso 2: escribir la nueva contraseña
│   └── partials/
│       └── navbar.php             # Barra superior reutilizable (usuario, rol, navegación, salir)
├── public/
│   ├── index.php                  # Front Controller (punto de entrada único, incluye todas las rutas)
│   └── assets/bootstrap/...       # CSS/JS de Bootstrap
├── storage/
│   └── correos_enviados.log       # Se crea solo; registro de enlaces de recuperación enviados
└── sql/
    └── schema.sql                 # Script: BD, tablas, usuarios y aprendiz de prueba
```

## Autenticación y roles: cómo se construyó

### 1. Cambios en la base de datos

Se agregó una tabla nueva, **`usuarios`**, independiente de `aprendices`
(ver `sql/schema.sql`):

```sql
CREATE TABLE usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(150) NOT NULL,
  usuario VARCHAR(50) NOT NULL UNIQUE,
  contrasena VARCHAR(255) NOT NULL,
  rol ENUM('aprendiz', 'docente', 'coordinador') NOT NULL,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

Decisiones de diseño de la tabla:
- **`usuario` es `UNIQUE`**: la base de datos misma impide que se registren
  dos personas con el mismo nombre de usuario, sin depender solo del código PHP.
- **`contrasena` es `VARCHAR(255)`**: un hash de `password_hash()` (bcrypt)
  ocupa 60 caracteres, pero se deja margen por si en el futuro se usa un
  algoritmo más largo (como Argon2).
- **`rol` es `ENUM`**: solo permite los 3 valores exactos (`aprendiz`,
  `docente`, `coordinador`); es la propia base de datos la que impide guardar
  un rol inválido por error de tipeo.
- **Nunca se guarda la contraseña en texto plano**: la columna `contrasena`
  siempre almacena el resultado de `password_hash()`, nunca lo que el usuario
  escribió.

El script también inserta 3 usuarios de prueba, uno por cada rol
(ver tabla de credenciales más abajo).

### 2. Cómo se creó el login (flujo completo)

1. **`views/auth/login.php`** muestra un formulario con `usuario` y
   `contrasena`, y un bloque que imprime los errores recibidos.
2. El formulario envía los datos por **POST** a `index.php?accion=autenticar`.
3. **`AuthController::login()`** ejecuta las validaciones en orden:
   - ¿El campo `usuario` llegó vacío? → error "El campo usuario es obligatorio."
   - ¿El campo `contrasena` llegó vacío? → error "El campo contraseña es obligatorio."
   - Si ambos campos vienen llenos, se busca el usuario en la base de datos
     con `UsuarioModel::obtenerPorUsuario()`.
   - Si no existe, o si `password_verify()` determina que la contraseña no
     coincide con el hash guardado, se agrega el error genérico
     **"Usuario o contraseña incorrectos."** (se usa el mismo mensaje en
     ambos casos a propósito, para no revelarle a un atacante si el usuario
     existe o no).
4. Si **no** hubo ningún error, `Auth::iniciarSesionUsuario()` guarda en
   `$_SESSION` el id, nombre, usuario y **rol** de la persona, y se redirige
   al listado.
5. Si hubo algún error, se vuelve a mostrar `login.php` pasándole el arreglo
   `$errores`, que la vista simplemente recorre e imprime.

Este flujo es el mismo patrón que ya usaban `guardar()` y `actualizar()` en
`AprendizController`: el Controlador valida y decide, el Modelo solo consulta,
la Vista solo muestra.

### 3. Cómo se crearon (y se aplican) los roles

Se creó una clase **`config/Auth.php`** que centraliza todo lo relacionado a
sesión y permisos, con dos métodos clave que actúan como "guardias de ruta":

- **`Auth::requerirAutenticacion()`**: si no hay sesión iniciada, redirige al
  login. Se usa en acciones que cualquier rol autenticado puede ver (como
  `listar()`).
- **`Auth::requerirRol(["docente", "coordinador"])`**: primero exige sesión,
  y además verifica que el rol de la sesión esté en la lista permitida; si no,
  redirige al listado con un mensaje de "no tienes permiso".

Estos métodos se llaman **al principio de cada método del Controlador**, antes
de tocar el Modelo o la Vista — así, el permiso se decide en un solo lugar
(el Controlador) y no se repite lógica de roles ni en el Modelo ni en la Vista.

Reglas de permisos aplicadas en este proyecto (a modo de ejemplo educativo):

| Acción | aprendiz | docente | coordinador |
|---|:---:|:---:|:---:|
| Ver listado (`listar`) | ✅ | ✅ | ✅ |
| Registrar aprendiz (`crear`/`guardar`) | ❌ | ✅ | ✅ |
| Editar aprendiz (`editar`/`actualizar`) | ❌ | ✅ | ✅ |
| Eliminar aprendiz (`eliminar`) | ❌ | ❌ | ✅ |

Además, las Vistas (`listar.php`, formularios) usan `Auth::tieneRol()` para
**ocultar** los botones que el usuario no podría usar de todas formas — esto
es solo una mejora de experiencia de usuario; la seguridad real siempre la
aplica el Controlador con `Auth::requerirRol()`, nunca la Vista por sí sola
(un usuario no debería poder ejecutar una acción solo porque "editó" la URL,
y en este proyecto no puede: aunque escriba `index.php?accion=eliminar&id=1`
a mano, el Controlador lo rechaza si su rol no es `coordinador`).

### 4. Usuarios de prueba

| Usuario | Correo | Contraseña | Rol |
|---|---|---|---|
| `aprendiz1` | `aprendiz1@ejemplo.com` | `aprendiz123` | aprendiz (vinculado a "Juan Pérez") |
| `docente1` | `docente1@ejemplo.com` | `docente123` | docente |
| `coordinador1` | `coordinador1@ejemplo.com` | `coordinador123` | coordinador |

## Dashboards por rol

Cada rol tiene su propia pantalla de inicio (`views/dashboard/...`), elegida
por `DashboardController::mostrarDashboard()` según `Auth::obtenerRol()`:

- **Coordinador**: tarjetas con el total de aprendices y de usuarios por rol,
  más los últimos 5 aprendices registrados (con editar/eliminar).
- **Docente**: total de aprendices y los últimos 5 registrados (puede editar,
  no eliminar).
- **Aprendiz**: solo SU propia información (nombre, ficha), nunca la lista
  completa de todos los aprendices. Esto se logra con una columna nueva,
  `usuarios.aprendiz_id`, que vincula la cuenta de un aprendiz con su fila en
  la tabla `aprendices`. Si esa columna es `NULL` (cuenta sin vincular
  todavía), se muestra un aviso en vez de datos vacíos.

El HTML repetido de "Hola, nombre / rol / cerrar sesión" se extrajo a
`views/partials/navbar.php`, incluido con `require` desde cada vista —así se
evita duplicar el mismo bloque en 7 archivos distintos.

## Recuperación de contraseña ("olvidé mi contraseña")

Se agregó un flujo de 4 pasos, todo dentro de `AuthController`:

1. **`views/auth/recuperar.php`** — la persona escribe su correo.
2. **`AuthController::enviarRecuperacion()`** valida que el correo no esté
   vacío y tenga formato válido (`filter_var(..., FILTER_VALIDATE_EMAIL)`).
   Si existe un usuario con ese correo, genera un **token aleatorio de 64
   caracteres** (`bin2hex(random_bytes(32))`, criptográficamente seguro) con
   **1 hora de validez**, lo guarda en `usuarios.token_recuperacion` /
   `token_expira`, y envía el correo con el enlace mediante `Correo::enviarRecuperacion()`.
   **Por seguridad, se muestra el mismo mensaje de éxito exista o no ese
   correo** en la base de datos — así nadie puede usar este formulario para
   "adivinar" qué correos están registrados.
3. Al hacer clic en el enlace (`index.php?accion=restablecer&token=...`),
   **`AuthController::mostrarRestablecer()`** busca ese token con
   `UsuarioModel::obtenerPorTokenValido()`, que solo lo encuentra si **no ha
   expirado** (`WHERE token_recuperacion = :token AND token_expira > NOW()`).
   Si es inválido o venció, se redirige al login con un aviso.
4. **`AuthController::restablecer()`** valida la nueva contraseña (no vacía,
   mínimo 6 caracteres, y que la confirmación coincida), la encripta con
   `password_hash()` y llama a
   `UsuarioModel::actualizarContrasenaYLimpiarToken()`, que guarda el nuevo
   hash **y borra el token** — así el mismo enlace no puede reutilizarse
   (token de un solo uso).

### Envío real del correo (PHPMailer + SMTP de Gmail)

`config/Correo.php` usa **PHPMailer** (incluido ya en `lib/PHPMailer/`, sin
necesitar Composer) para conectarse directamente al servidor SMTP de Gmail
y **entregar el correo de verdad** a la bandeja del destinatario, en vez de
depender de la función nativa `mail()` de PHP (que casi nunca funciona en un
XAMPP/WAMP local porque no hay servidor SMTP configurado en el equipo).

**Configuración obligatoria (una sola vez), dentro de `config/Correo.php`:**

1. Entra a la cuenta de Gmail que vas a usar para ENVIAR los correos.
2. Activa la verificación en 2 pasos: https://myaccount.google.com/security
   (Gmail exige esto antes de dejarte crear una contraseña de aplicación).
3. Genera una "Contraseña de aplicación" en:
   https://myaccount.google.com/apppasswords
   (elige app "Correo", dispositivo "Otro", y ponle un nombre como
   `SenaRegistro`). Gmail te da una clave de 16 letras — **esa** es la que
   necesitas, no la contraseña normal de tu cuenta.
4. Reemplaza estas dos constantes al inicio de `config/Correo.php`:
   ```php
   const GMAIL_REMITENTE      = "tu_correo_del_proyecto@gmail.com";
   const GMAIL_CONTRASENA_APP = "xxxx xxxx xxxx xxxx"; // la clave de 16 letras
   ```

Con eso configurado, cuando alguien pida "olvidé mi contraseña" con un
correo real (Gmail, Outlook, el que sea), el enlace de recuperación **sí
llegará de verdad** a esa bandeja de entrada.

Cada intento de envío, exitoso o no, también se sigue registrando en
`storage/correos_enviados.log` (incluyendo el mensaje de error de Gmail si
algo falla, por ejemplo credenciales mal puestas), útil para depurar sin
tener que revisar la bandeja de entrada cada vez.

## Cómo ejecutar el proyecto

1. Crea la base de datos ejecutando `sql/schema.sql` en MySQL/MariaDB (por
   ejemplo desde phpMyAdmin o la consola `mysql`).
2. Revisa `config/Database.php` y ajusta host, puerto, usuario y clave si tu
   servidor local es distinto (por defecto: `localhost`, puerto `3307`,
   usuario `root`, sin clave).
3. Copia toda la carpeta `sena_registro_v2/` a tu servidor local
   (por ejemplo, la carpeta `htdocs` de XAMPP).
4. Abre en el navegador: `http://localhost/sena_registro_v2/public/index.php`
5. Verás el formulario de **login**; usa cualquiera de los 3 usuarios de
   prueba (ver tabla arriba) para entrar con un rol distinto y comprobar qué
   botones aparecen o desaparecen.
6. Desde el listado puedes registrar, editar o eliminar aprendices según lo
   permita tu rol; todas las acciones pasan por `index.php?accion=...`.
7. Para probar la recuperación de contraseña: primero configura Gmail como
   se explica en la sección "Envío real del correo" de arriba. Luego, haz
   clic en **"¿Olvidaste tu contraseña?"** en el login, escribe un correo
   real (puede ser cualquiera, no solo los de prueba), y revisa esa bandeja
   de entrada — el enlace debe llegar en segundos. Si algo falla, revisa
   `storage/correos_enviados.log` para ver el mensaje de error exacto.

## Mapa de acciones (rutas)

| URL | Acción del Controlador | Requiere sesión / rol | Qué hace |
|---|---|---|---|
| `index.php?accion=login` | `AuthController::mostrarLogin()` | Ninguno | Muestra el formulario de login |
| `index.php?accion=autenticar` (POST) | `AuthController::login()` | Ninguno | Valida usuario/contraseña e inicia sesión |
| `index.php?accion=recuperar` | `mostrarRecuperar()` | Ninguno | Paso 1: formulario para pedir el correo |
| `index.php?accion=enviar_recuperacion` (POST) | `enviarRecuperacion()` | Ninguno | Paso 2: genera el token y envía el correo |
| `index.php?accion=restablecer&token=...` | `mostrarRestablecer()` | Token válido | Paso 3: formulario de nueva contraseña |
| `index.php?accion=restablecer` (POST) | `restablecer()` | Token válido | Paso 4: guarda la nueva contraseña |
| `index.php?accion=logout` | `AuthController::logout()` | Sesión iniciada | Cierra la sesión |
| `index.php?accion=dashboard` | `DashboardController::mostrarDashboard()` | Cualquier rol | Pantalla de inicio distinta según el rol |
| `index.php?accion=listar` | `AprendizController::listar()` | Cualquier rol | Muestra la tabla de aprendices |
| `index.php?accion=crear` | `mostrarFormularioCrear()` | **coordinador** | Muestra el formulario vacío (el docente ya no puede crear) |
| `index.php?accion=guardar` (POST) | `guardar()` | **coordinador** | Inserta el nuevo aprendiz |
| `index.php?accion=editar&id=N` | `mostrarFormularioEditar()` | docente, coordinador | Muestra el formulario con los datos del aprendiz N |
| `index.php?accion=actualizar` (POST) | `actualizar()` | docente, coordinador | Guarda los cambios del aprendiz |
| `index.php?accion=aprendices_inactivar&id=N` | `inactivar()` | docente, coordinador | Marca al aprendiz N como "retirado" (sin borrarlo) |
| `index.php?accion=aprendices_activar&id=N` | `activar()` | docente, coordinador | Reactiva a un aprendiz retirado |
| `index.php?accion=eliminar&id=N` | `eliminar()` | coordinador | Borra al aprendiz N por completo (y sus notas, en cascada) |
| `index.php?accion=notas&aprendiz_id=N` | `NotaController::gestionar()` | docente, coordinador | Ver/subir/eliminar notas del aprendiz N |
| `index.php?accion=notas_guardar` (POST) | `guardar()` | docente, coordinador | Registra una nota nueva |
| `index.php?accion=notas_eliminar&id=N` | `eliminar()` | docente, coordinador | Elimina la nota N |
| `index.php?accion=mis_notas` | `misNotas()` | aprendiz | El aprendiz ve SOLO sus propias notas |
| `index.php?accion=registro` | `AuthController::mostrarRegistro()` | Ninguno | Formulario de auto-registro (solo aprendiz o coordinador) |
| `index.php?accion=registrar` (POST) | `registrar()` | Ninguno | Crea la cuenta y, si es aprendiz, también su ficha; inicia sesión automáticamente |
| `index.php?accion=usuarios` | `UsuarioController::listar()` | coordinador | Lista TODAS las cuentas del sistema (aprendiz, docente, coordinador) |
| `index.php?accion=usuarios_crear` | `mostrarFormularioCrear()` | coordinador | Formulario para crear cualquier cuenta, incluidos docentes |
| `index.php?accion=usuarios_guardar` (POST) | `guardar()` | coordinador | Inserta la nueva cuenta |
| `index.php?accion=usuarios_editar&id=N` | `mostrarFormularioEditar()` | coordinador | Formulario de edición de la cuenta N (contraseña opcional) |
| `index.php?accion=usuarios_actualizar` (POST) | `actualizar()` | coordinador | Guarda los cambios de la cuenta |
| `index.php?accion=usuarios_eliminar&id=N` | `eliminar()` | coordinador | Elimina la cuenta N (no permite eliminar la propia) |

## Registro de nuevos usuarios y CRUD de cuentas (nuevo)

- **Registro público** (`accion=registro`, enlazado desde el login): cualquier
  visitante puede crear su propia cuenta como **aprendiz** o **coordinador**.
  Si elige "aprendiz", el formulario pide también la **ficha** y, al guardar,
  se crea automáticamente su fila en la tabla `aprendices` y queda vinculada
  a la cuenta nueva (`usuarios.aprendiz_id`). El rol **docente** NO aparece
  en este formulario a propósito.
- **CRUD de usuarios** (`accion=usuarios*`, exclusivo del coordinador, con
  enlace "Gestionar usuarios" en la barra superior y en su dashboard): permite
  **crear, editar y eliminar** cualquier cuenta, incluidas las de **docente**
  (que es como el proyecto pide que el coordinador dé de alta a los
  docentes). Al crear/editar una cuenta con rol "aprendiz", el coordinador
  puede escribir una ficha nueva o vincularla a un aprendiz ya existente sin
  cuenta. La contraseña es opcional al editar (en blanco = no cambia). Un
  coordinador no puede eliminar su propia cuenta activa, para no perder el
  acceso al sistema.

## Permisos del docente, notas y retiro de aprendices (nuevo)

Se ajustaron los permisos del rol **docente** y se agregó el módulo de notas:

- **El docente YA NO puede crear aprendices nuevos** (`accion=crear` /
  `accion=guardar` ahora exigen rol `coordinador` exclusivamente). El alta
  inicial de un aprendiz queda en manos del coordinador.
- **El docente SÍ puede**:
  - Ver el listado completo de aprendices (`accion=listar`).
  - Editar los datos de un aprendiz (`accion=editar` / `accion=actualizar`).
  - Subir, ver y eliminar notas de cualquier aprendiz (`accion=notas*`).
  - Marcar a un aprendiz como **retirado** si se retira del programa
    (`accion=aprendices_inactivar`), y reactivarlo si vuelve
    (`accion=aprendices_activar`).
- **El docente NO puede** eliminar un aprendiz por completo (borrado
  permanente); esa acción sigue siendo exclusiva del coordinador
  (`accion=eliminar`), ya que borraría también el historial de notas.

### Estado del aprendiz: "activo" vs "retirado"

Se agregó la columna `aprendices.estado` (`ENUM('activo','retirado')`). En
vez de borrar el registro de un aprendiz que se retira (lo que eliminaría su
historial de notas y desvincularía su cuenta), el sistema simplemente lo
marca como `retirado`:

- Se ve con una insignia gris "Retirado" en el listado, en vez del verde
  "Activo".
- Un aprendiz retirado deja de aparecer como candidato para vincular a una
  cuenta de usuario nueva (en el registro público y en el CRUD de usuarios),
  pero conserva su historial de notas.
- Se puede reactivar en cualquier momento con el botón "Reactivar".

### Módulo de notas

Se agregó la tabla `notas` (asignatura, nota de 0.0 a 5.0, quién la
registró y cuándo), con su propio `NotaModel` y `NotaController`:

- **Docente y coordinador**: desde el listado de aprendices, botón "Notas"
  → pantalla con el historial de ese aprendiz y un formulario para subir
  una nota nueva o eliminar una existente.
- **Aprendiz**: enlace "Mis notas" en la barra superior y en su dashboard →
  ve únicamente sus propias notas, en modo solo lectura. El Controlador usa
  siempre el `aprendiz_id` guardado en su sesión (nunca un valor de la URL),
  así que es imposible que un aprendiz consulte las notas de otro cambiando
  el enlace.

Si tu base de datos ya existía antes de esta versión, ejecuta las
instrucciones de migración que están comentadas al final de
`sql/schema.sql` (agregar la columna `estado` y crear la tabla `notas`).
