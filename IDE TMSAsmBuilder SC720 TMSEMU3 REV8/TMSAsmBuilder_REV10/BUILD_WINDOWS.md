# Build TMSAsmBuilder REV10 on Windows

## Requirements

- Windows 10 or Windows 11
- .NET 8 SDK
- This repo folder with `Tools\sjasmplus.exe` included

## Publish portable folder

```powershell
cd TMSAsmBuilder_REV10_pro_repo
.\scripts\publish-win-x64.ps1
```

Output:

```text
TMSAsmBuilder_REV10_ready_to_run\TMSAsmBuilder.exe
```

## Run from source

```powershell
dotnet run --project .\src\TMSAsmBuilder\TMSAsmBuilder.csproj
```

The app searches upward from the executable/current directory until it finds `Tools\sjasmplus.exe` and `Libs`.  That lets it work both from source and from the published portable folder.
