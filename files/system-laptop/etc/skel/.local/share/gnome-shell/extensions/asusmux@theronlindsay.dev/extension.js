import Gio from "gi://Gio";
import GObject from "gi://GObject";
import St from "gi://St";
import Clutter from "gi://Clutter";
import * as Main from "resource:///org/gnome/shell/ui/main.js";
import * as QuickSettings from "resource:///org/gnome/shell/ui/quickSettings.js";
import * as PopupMenu from "resource:///org/gnome/shell/ui/popupMenu.js";
import * as ModalDialog from "resource:///org/gnome/shell/ui/modalDialog.js";
import { Extension } from "resource:///org/gnome/shell/extensions/extension.js";

// 1. Create the Menu Toggle
const GpuMenuToggle = GObject.registerClass(
  class GpuMenuToggle extends QuickSettings.QuickMenuToggle {
    constructor() {
      super({
        title: "GPU Mode",
        subtitle: "Detecting...",
        iconName: "video-display-symbolic",
        toggleMode: false, // False makes the whole button open the dropdown
      });

      this._addGpuMode("Integrated", [
        "pkexec",
        "sh",
        "-c",
        "asusctl armoury set dgpu_disable 1 && asusctl armoury set gpu_mux_mode 1",
      ]);
      this._addGpuMode("Hybrid", [
        "pkexec",
        "sh",
        "-c",
        "asusctl armoury set dgpu_disable 0 && asusctl armoury set gpu_mux_mode 1",
      ]);
      this._addGpuMode("Dedicated", [
        "pkexec",
        "sh",
        "-c",
        "asusctl armoury set dgpu_disable 0 && asusctl armoury set gpu_mux_mode 0",
      ]);

      this.menu.connect("open-state-changed", (_menu, isOpen) => {
        if (isOpen) this._refreshCurrentMode();
      });

      this._refreshCurrentMode();
    }

    _addGpuMode(modeName, cmdArray) {
      const item = new PopupMenu.PopupMenuItem(modeName);
      item.connect("activate", async () => {
        this.subtitle = `Applying ${modeName}...`;

        try {
          const { stdout, stderr } = await this._runCommand(cmdArray);
          await this._refreshCurrentMode();

          const output = `${stdout}\n${stderr}`.trim();
          this._showOutputAndRestart(modeName, output);
        } catch (error) {
          this.subtitle = "Mode apply failed";
          console.error(
            `[GPU Switcher] Failed to set mode ${modeName}: ${error}`,
          );
          this._showOutputAndRestart(
            modeName,
            `Error: ${error.message || error}`,
            false,
          );
        }
      });
      this.menu.addMenuItem(item);
    }

    _showOutputAndRestart(modeName, output, success = true) {
      const dialog = new ModalDialog.ModalDialog();

      const title = success
        ? `${modeName} Mode Applied`
        : `${modeName} Mode Failed`;
      const titleLabel = new St.Label({
        text: title,
        style_class: "headline",
        x_align: Clutter.ActorAlign.CENTER,
      });
      dialog.contentLayout.add_child(titleLabel);

      const outputBox = new St.BoxLayout({
        vertical: true,
        style_class: "run-dialog",
        style:
          "padding: 12px; background-color: rgba(0, 0, 0, 0.3); border-radius: 8px; margin: 12px 0;",
      });

      const outputLabel = new St.Label({
        text: output || "No output",
        style_class: "run-dialog-label",
        style: "font-family: monospace; font-size: 10pt;",
      });
      outputBox.add_child(outputLabel);
      dialog.contentLayout.add_child(outputBox);

      if (success) {
        const messageLabel = new St.Label({
          text: "A restart is required for the GPU mode change to take effect.",
          x_align: Clutter.ActorAlign.CENTER,
          style: "margin-top: 12px;",
        });
        dialog.contentLayout.add_child(messageLabel);

        dialog.addButton({
          label: "Restart Now",
          action: () => {
            dialog.close();
            this._restartSystem();
          },
          default: true,
        });

        dialog.addButton({
          label: "Restart Later",
          action: () => {
            dialog.close();
          },
          key: Clutter.KEY_Escape,
        });
      } else {
        dialog.addButton({
          label: "Close",
          action: () => {
            dialog.close();
          },
          key: Clutter.KEY_Escape,
        });
      }

      dialog.open();
    }

    _restartSystem() {
      try {
        Gio.Subprocess.new(["systemctl", "reboot"], Gio.SubprocessFlags.NONE);
      } catch (error) {
        console.error(`[GPU Switcher] Failed to restart: ${error}`);
      }
    }

    _runCommand(cmdArray) {
      return new Promise((resolve, reject) => {
        try {
          const proc = Gio.Subprocess.new(
            cmdArray,
            Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE,
          );

          proc.communicate_utf8_async(null, null, (subprocess, result) => {
            try {
              const [ok, stdout, stderr] =
                subprocess.communicate_utf8_finish(result);

              if (!ok || !subprocess.get_successful()) {
                const details = (stderr || stdout || "").trim();
                reject(
                  new Error(
                    details || `Exit status ${subprocess.get_exit_status()}`,
                  ),
                );
                return;
              }

              resolve({ stdout: stdout || "", stderr: stderr || "" });
            } catch (error) {
              reject(error);
            }
          });
        } catch (error) {
          reject(error);
        }
      });
    }

    async _refreshCurrentMode() {
      try {
        const { stdout, stderr } = await this._runCommand([
          "asusctl",
          "armoury",
          "list",
        ]);
        const modeName = this._parseCurrentMode(`${stdout}\n${stderr}`);
        this.subtitle = modeName;
      } catch (error) {
        this.subtitle = "Unknown";
        console.error(`[GPU Switcher] Could not read current mode: ${error}`);
      }
    }

    _parseCurrentMode(output) {
      const values = {};
      let currentControl = null;

      for (const line of output.split("\n")) {
        const controlMatch = line.match(/^([a-z0-9_]+):\s*$/i);
        if (controlMatch) {
          currentControl = controlMatch[1].toLowerCase();
          continue;
        }

        if (!currentControl) continue;

        const currentMatch = line.match(/^\s*current:\s*(.+)$/i);
        if (!currentMatch) continue;

        const selected = this._extractSelectedValue(currentMatch[1]);
        if (selected !== null) values[currentControl] = selected;
      }

      const dgpuDisable = values.dgpu_disable;
      const gpuMuxMode = values.gpu_mux_mode;

      if (dgpuDisable === 1 && gpuMuxMode === 1) return "Integrated";

      if (dgpuDisable === 0 && gpuMuxMode === 1) return "Hybrid";

      if (dgpuDisable === 0 && gpuMuxMode === 0) return "Dedicated";

      return "Unknown";
    }

    _extractSelectedValue(currentField) {
      const selectedOptionMatch = currentField.match(/\((-?\d+)\)/);
      if (selectedOptionMatch)
        return Number.parseInt(selectedOptionMatch[1], 10);

      const rangedValueMatch = currentField.match(/\[(-?\d+)\]/);
      if (rangedValueMatch) return Number.parseInt(rangedValueMatch[1], 10);

      const rawValueMatch = currentField.match(/-?\d+/);
      if (rawValueMatch) return Number.parseInt(rawValueMatch[0], 10);

      return null;
    }
  },
);

// 2. Create the System Indicator wrapper
const GpuIndicator = GObject.registerClass(
  class GpuIndicator extends QuickSettings.SystemIndicator {
    constructor() {
      super();
      this._toggle = new GpuMenuToggle();
      this.quickSettingsItems.push(this._toggle);
    }
  },
);

// 3. Main Extension Class
export default class GpuSwitcherExtension extends Extension {
  enable() {
    this._indicator = new GpuIndicator();
    // Inject the toggle into the Quick Settings menu
    Main.panel.statusArea.quickSettings.addExternalIndicator(this._indicator);
  }

  disable() {
    // Clean up everything when the extension is turned off
    this._indicator.quickSettingsItems.forEach((item) => item.destroy());
    this._indicator.destroy();
    this._indicator = null;
  }
}
