# Build and Run on Windows

## Requirements

- Windows 10 or newer.
- .NET 8 SDK for building/running from source.
- `sjasmplus.exe` in `TMSAsmBuilder\Tools`.
- TMS support ASM files in `TMSAsmBuilder\Libs`.

## Run from source

From the repo root:

```bat
run_gui.bat
```

or:

```bat
dotnet run --project TMSAsmBuilder\TMSAsmBuilder.csproj
```

## Build release

```bat
build_gui.bat
```

The normal release build output is under:

```text
TMSAsmBuilder\bin\Release\net8.0-windows
```

The project file copies these folders into the build output:

```text
Assets
Libs
Tools
Templates
Builds\README.txt
Out\README.txt
Work\README.txt
```

That matters because the running program uses its own executable folder as the project root.

## Publish a portable folder

Run:

```bat
publish_portable.bat
```

That creates:

```text
Release\TMSAsmBuilder_Portable
```

You can copy that portable folder to another Windows PC. If using framework-dependent publishing, that PC still needs the .NET Desktop Runtime installed. If you want a fully self-contained publish, edit `publish_portable.bat` and use the commented self-contained command.
