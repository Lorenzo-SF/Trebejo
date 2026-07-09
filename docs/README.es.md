# Trebejo

Utilidades de sistema con dependencia de shell extraídas de [Apero](https://hex.pm/packages/apero).

## ¿Por qué Trebejo?

Apero se dividió en dos paquetes:

| Paquete | Contenido |
|---------|-----------|
| **apero** (≥ 3.0.0) | Wrappers puros de stdlib — Env, Conf, Retry, Crypto, Cache, File trees/paths, OS type/hostname, Proc which/command\_exists? |
| **trebejo** | Operaciones con shell — Docker, Git, SSH, K8s, Compress, Network, OS info (arch, distro, kernel, cpu, memory), Proc listing/signalling, File watch |

## Módulos

| Módulo | Descripción |
|--------|-------------|
| `Trebejo.Docker` | Gestión de contenedores Docker/Podman |
| `Trebejo.Git` | Operaciones con repositorios Git |
| `Trebejo.SSH` | Conexiones SSH y comandos remotos |
| `Trebejo.K8s` | Gestión de recursos Kubernetes |
| `Trebejo.Compress` | Creación y extracción de archivos comprimidos |
| `Trebejo.Network` | Interfaces de red y conectividad |
| `Trebejo.OS` | Metadatos del SO: arch, distro, kernel, CPU, memoria, info, root, detección WSL/container |
| `Trebejo.Proc` | Listado de procesos, señales, lsof, fuser, logs |
| `Trebejo.File` | Vigilancia del sistema de archivos |
| `Trebejo.File.IO` | Información de uso de disco |

> Las funciones puras se delegan a `Apero.*` — este paquete depende de apero.

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
