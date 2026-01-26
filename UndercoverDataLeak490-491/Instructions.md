# Rojo Setup & Usage Instructions

This document explains how to install Rojo, connect it to Roblox Studio, and properly organize scripts in the project.

---

## Prerequisites

- Visual Studio Code
- Roblox Studio
- A Roblox experience created and opened in Roblox Studio

---

## Installing Rojo & Roblox LSP

1. Open **Visual Studio Code**
2. Go to the **Extensions** tab
3. Install the following extensions:
   - **Rojo**
   - **Roblox LSP**

---

## VS Code Instructions

1. Open the Command Palette:

Ctrl + Shift + P or Cmd + Shift + P

2. Select:

Rojo: Open Menu


3. Click the following options:
- **Install Rojo**
- **Install Roblox Studio Plugin**

4. In the Rojo menu, click:

Add default.project.json


This will generate a `default.project.json` file required for syncing with Roblox Studio.

---

## Roblox Studio Instructions

1. Open **Roblox Studio**
2. When prompted by the Rojo plugin, click:

Connect


3. Roblox Studio will now sync with the project in VS Code.

---

## Project Structure & Script Placement

All scripts should be placed inside the `src` folder.

### Script Types

- **Server Scripts**
- Location: `src/server`
- File extension: `.server.luau`

- **Client Scripts**
- Location: `src/client`
- File extension: `.client.luau`

- **Shared Scripts / Modules**
- Location: anywhere inside `src`
- File extension: `.luau`

---

## Example Project Structure

src/
├── server/
│ └── main.server.luau
├── client/
│ └── ui.client.luau
└── shared/
└── utils.luau


---

## Notes

- Rojo automatically syncs files between VS Code and Roblox Studio while connected.
- Ensure script file extensions are correct, or scripts may not run as expected.
- Keep all Roblox-related code inside the `src` directory to avoid sync issues.

---

Happy developing 🚀