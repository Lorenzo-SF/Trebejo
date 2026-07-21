# Trebejo

Utilidades de sistema dependientes de shell extraídas de [Apero](https://hex.pm/packages/apero).

## ¿Por qué Trebejo?

Apero se dividió en dos paquetes:

| Paquete | Contenido |
|---------|-----------|
| **apero** (≥ 3.0.0) | Wrappers puros sobre stdlib — Env, Conf, Retry, Crypto, Cache, árboles/rutas de File, tipo/hostname/distro/container/WSL de OS, Proc which/command\_exists? |
| **trebejo** | Operaciones dependientes de shell — Docker, Git, SSH, Kubernetes, Compress, Network, info de OS (arch, kernel, cpu, memoria, root), listado/señalización de procesos, vigilancia de archivos, Image, instalación de paquetes |

## Módulos

| Módulo | Descripción |
|--------|-------------|
| `Trebejo.Docker` | Ciclo de vida de contenedores Docker / Podman |
| `Trebejo.Git` | Operaciones de repositorio Git (fachada sobre `Trebejo.Git.Local`) |
| `Trebejo.Git.Local` | Wrappers de bajo nivel sobre el CLI de git (commit, branch, log, churn, …) |
| `Trebejo.SSH` | Conexiones SSH y ejecución remota de comandos |
| `Trebejo.Kubernetes` | Wrappers de kubectl para recursos del clúster |
| `Trebejo.Compress` | Creación y extracción de archivos comprimidos (zip, tar, gzip) |
| `Trebejo.Network` | Sondas de interfaz de red y conectividad |
| `Trebejo.OS` | Metadatos del SO: arch, kernel, CPU, memoria, root — basado en shell. La detección pura (tipo, hostname, distro) vive en `Apero.OS` |
| `Trebejo.Proc` | Listado de procesos, señalización, lsof, fuser, acceso a logs |
| `Trebejo.Packages` | Instalación y consulta de paquetes (apt, brew, pacman, …) |
| `Trebejo.Image` | Ayudas de inspección de imágenes de contenedor / VM |
| `Trebejo.File` | Vigilancia del sistema de archivos vía Arrea.WorkerSupervisor |
| `Trebejo.File.IO` | Informes de uso de disco |
| `Trebejo.SafeCommand` | Wrapper validado sobre `Arrea.Command.execute/2` — punto único de entrada para toda ejecución de shell |
| `Trebejo.Util` | `run_cmd/3`, `run_cmd_legacy/3`, `run_ok/3` — todo enrutado por `SafeCommand.execute/3` |

> Las funciones basadas en shell pasan por `Arrea.Command` a través de `Trebejo.SafeCommand` para una validación consistente y argumentos con quoting POSIX. La detección pura (tipo de SO, hostname, distro) vive en `Apero.OS` — úsala directamente.

## Instalación

Añade `trebejo` a tu `mix.exs`:

```elixir
def deps do
  [
    {:trebejo, "~> 1.0.0"}
  ]
end
```

## Documentación

Documentación completa en [https://hexdocs.pm/trebejo](https://hexdocs.pm/trebejo).

Generada con [ExDoc](https://github.com/elixir-lang/ex_doc).
