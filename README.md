# Better Netrunning - Fix Project

This Fix Project for base game version 2.X is based on Better Netrunning, originally created by finley243.
Full credit for the mod's creation, concept, implementation, and system goes to finley243, the original author

For detailed descriptions, please refer to their mod page: [Better Netrunning – Hacking Reworked](https://www.nexusmods.com/cyberpunk2077/mods/2302).
If you choose to endorse my mod page, I kindly ask that you also endorse theirs.

---

## 📚 Documentation

### Core Documentation

- **[ARCHITECTURE_DESIGN.md](ARCHITECTURE_DESIGN.md)** - System Architecture & Design Document
  - Complete architectural overview of Better Netrunning
  - Module structure and dependencies
  - Core subsystems (Breach Protocol, Remote Breach, Quickhacks, RadialUnlock)
  - Data flow and design patterns
  - Configuration system and extension points
  - Performance considerations

- **[BREACH_SYSTEM_REFERENCE.md](BREACH_SYSTEM_REFERENCE.md)** - Breach System Technical Reference
  - Detailed breach type comparison (AP Breach, Unconscious NPC Breach, Remote Breach)
  - Daemon injection logic and filtering pipeline
  - Minigame parameters and processing flow
  - Network access relaxation features
  - Device-specific daemon determination

- **[TODO.md](TODO.md)** - Development Roadmap & Task List
  - High priority tasks with completion status
  - Customizable key bindings implementation plan
  - MOD compatibility improvements (Phase 2 & 3)
  - RadialBreach integration status
  - Technical implementation details and success criteria

### Release Notes

- **[RELEASE_NOTES_v0.5.0.md](RELEASE_NOTES_v0.5.0.md)** - Version 0.5.0 Release Notes
  - Auto-Daemon System (PING auto-execution, Datamine scaling)
  - RemoteBreach toggle controls
  - Lua module refactoring (init.lua 424→33 lines)
  - Code quality improvements (nesting reduction)
  - Bug fixes and technical details

---

## 🎯 Features

- **Progressive Subnet System**: Unlock Camera/Turret/NPC subnets independently
- **Remote Breach**: Breach devices without physical Access Points
- **Auto-Daemon System**: Automatic PING and Datamine execution
- **RadialUnlock**: 50m radius breach tracking for standalone devices
- **Unconscious NPC Breach**: Direct breach on unconscious NPCs
- **Granular Control**: Per-device-type RemoteBreach toggles

---

## 🔧 Requirements

- **Game Version**: Cyberpunk 2077 2.X
- **Red4ext**: Required
- **Redscript**: Required
- **CustomHackingSystem (HackingExtensions)**: Required for RemoteBreach functionality
- **Native Settings UI**: Optional (recommended for settings management)
- **RadialBreach MOD**: Optional (enhanced physical distance filtering)

---

## 📥 Installation

1. Download the latest release from [Releases](https://github.com/SaganoKei/Better-Netrunning-Fix/releases)
2. Extract all files to your Cyberpunk 2077 game directory
3. Install required dependencies (Red4ext, Redscript, CustomHackingSystem)
4. Launch the game

---

## ⚙️ Configuration

Settings can be configured via:
- Native Settings UI (recommended)
- `r6/scripts/BetterNetrunning/config.reds` (manual editing)
- CET console (advanced users)

See [ARCHITECTURE_DESIGN.md](ARCHITECTURE_DESIGN.md#configuration-system) for detailed configuration options.

---

## 🤝 Contributing

Contributions are welcome! Please check [TODO.md](TODO.md) for current development priorities.

---

## 📜 Credits

**Original Mod**: [Better Netrunning](https://www.nexusmods.com/cyberpunk2077/mods/2302) by finley243

**Fix Project**: SaganoKei

**Contributors**:
- [@schizoabe](https://github.com/schizoabe) - Bug fix contributions

**Collaboration & Compatibility**:
- **BiasNil** - Developer of [Daemon Netrunning (Revamp)](https://www.nexusmods.com/cyberpunk2077/mods/12523), compatibility integration
- **lorddarkflare** - Developer of [Breach Takedown Improved](https://www.nexusmods.com/cyberpunk2077/mods/14171), technical collaboration
- **rpierrecollado** - Integration features, CustomHackingSystem prototyping, and testing
