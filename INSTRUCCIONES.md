# Proyecto esqueleto — `sena_registro_v2`

Este paquete es el punto de partida del proyecto. **No está completo a propósito**:
solo trae lo que no tendría sentido que programaras desde cero (librerías externas,
estilos, y el script de base de datos). El resto lo vas a construir tú, siguiendo la
guía de clase, aplicando el patrón MVC.

## Qué ya viene incluido (no lo modifiques ni lo recrees)

| Carpeta/archivo | Qué es | Por qué ya está |
|---|---|---|
| `lib/PHPMailer/` | Librería externa para enviar correos reales por SMTP | Es código de terceros (open source), no se programa, se reutiliza |
| `public/assets/bootstrap/` | CSS y JS de Bootstrap | Es una librería de diseño externa, igual que PHPMailer |
| `sql/schema.sql` | Script con las tablas `aprendices`, `usuarios`, `notas` | Punto de partida de la base de datos; ejecútalo en tu gestor MySQL |
| `README.md` | Teoría de MVC y documentación de referencia del proyecto original | Material de consulta, léelo antes de empezar |

## Qué carpetas debes CREAR tú (siguiendo el patrón MVC)

Dentro de esta misma carpeta raíz, debes crear:

```
sena_registro_v2/
├── config/              ← TÚ la creas
│   ├── Database.php
│   ├── Auth.php
│   └── Correo.php
├── models/               ← TÚ la creas
│   ├── AprendizModel.php
│   ├── UsuarioModel.php
│   └── NotaModel.php
├── controllers/          ← TÚ la creas
│   ├── AprendizController.php
│   ├── AuthController.php
│   ├── DashboardController.php
│   ├── UsuarioController.php
│   └── NotaController.php
├── views/                ← TÚ la creas (con sus subcarpetas)
│   ├── aprendices/
│   ├── auth/
│   ├── dashboard/
│   ├── notas/
│   ├── partials/
│   └── usuarios/
├── public/
│   └── index.php         ← TÚ lo creas (assets/ ya está)
└── storage/               ← NO la crees: aparece sola cuando el
                              código intente escribir el primer log
```

## Orden recomendado para construirlas

Sigue las 11 fases y 64 pasos de la guía de clase (`Modulos_MVC_y_Guia_Construccion_sena_registro_v3`),
en resumen:

1. Base de datos (`sql/schema.sql`, ya incluido).
2. `config/Database.php` y `config/Auth.php`.
3. `public/index.php` (Front Controller, arranca simple).
4. Módulo Aprendices completo (Modelo → Controlador → Vistas) — es tu plantilla.
5. Módulo de Login (`AuthController.php` + `views/auth/`).
6. Roles y permisos (ajustes en los controladores ya creados).
7. Dashboard por rol.
8. Módulo de Notas.
9. Módulo de gestión de Usuarios.
10. Recuperación de contraseña (usa `config/Correo.php` + la librería `lib/PHPMailer/` que ya tienes).

No copies estas carpetas de ningún otro lado — la idea es que las escribas tú mismo,
archivo por archivo, aplicando lo visto en clase.
