// FILE: website/drive_sync.js
// Pharoah ERP - Google Drive 2-Way Multi-Tenant Sync Engine

const GoogleDriveSync = {
    // Current Tenant Context
    config: {
        apiUrl: "",        // User's Google Apps Script Webhook URL
        userEmail: "",     // User's Gmail
        isSyncEnabled: true,
        lastSyncTime: null
    },

    // 1. Initialize Sync Configuration
    init() {
        const saved = localStorage.getItem("pharoah_drive_sync_config");
        if (saved) {
            try {
                this.config = JSON.parse(saved);
                this.updateUIStatus();
            } catch (e) {
                console.error("Drive config load error:", e);
            }
        }
    },

    // 2. Save User's Connection Settings
    saveConfig(apiUrl, userEmail) {
        this.config.apiUrl = apiUrl.trim();
        this.config.userEmail = userEmail.trim();
        this.config.isSyncEnabled = true;
        localStorage.setItem("pharoah_drive_sync_config", JSON.stringify(this.config));
        this.updateUIStatus();
    },

    // 3. Upload Full ERP Database to Google Drive (App or Web -> Drive)
    async pushToDrive(dataPayload) {
        if (!this.config.apiUrl || !this.config.isSyncEnabled) {
            console.log("Drive Sync is OFF or URL not configured.");
            return false;
        }

        try {
            const response = await fetch(this.config.apiUrl, {
                method: "POST",
                mode: "no-cors", // Allows cross-origin Google Apps Script webhook
                headers: {
                    "Content-Type": "application/json"
                },
                body: JSON.stringify({
                    action: "SAVE_DATABASE",
                    tenantEmail: this.config.userEmail,
                    timestamp: new Date().toISOString(),
                    payload: dataPayload
                })
            });

            this.config.lastSyncTime = new Date().toLocaleTimeString();
            this.updateUIStatus();
            console.log("✅ Data successfully pushed to Google Drive.");
            return true;
        } catch (error) {
            console.error("❌ Drive Push Error:", error);
            return false;
        }
    },

    // 4. Fetch Full ERP Database from Google Drive (Drive -> Web or App)
    async pullFromDrive() {
        if (!this.config.apiUrl || !this.config.isSyncEnabled) {
            return null;
        }

        try {
            const fetchUrl = `${this.config.apiUrl}?action=GET_DATABASE&tenantEmail=${encodeURIComponent(this.config.userEmail)}`;
            const response = await fetch(fetchUrl);
            
            if (!response.ok) throw new Error("Network response was not ok");

            const result = await response.json();
            if (result && result.payload) {
                this.config.lastSyncTime = new Date().toLocaleTimeString();
                this.updateUIStatus();
                console.log("✅ Latest data pulled from Google Drive.");
                return result.payload;
            }
            return null;
        } catch (error) {
            console.error("❌ Drive Pull Error:", error);
            return null;
        }
    },

    // 5. Update Status Banner on Web UI
    updateUIStatus() {
        const tenantEl = document.getElementById("tenantLabel");
        const kpiStatusEl = document.getElementById("kpi-status");

        if (tenantEl) {
            if (this.config.userEmail) {
                tenantEl.innerText = `Google Drive: ${this.config.userEmail}`;
            } else {
                tenantEl.innerText = "Offline / Local Demo Mode";
            }
        }

        if (kpiStatusEl) {
            if (this.config.apiUrl) {
                kpiStatusEl.innerText = `🟢 Synced (${this.config.lastSyncTime || 'Ready'})`;
                kpiStatusEl.style.color = "var(--accent-emerald)";
            } else {
                kpiStatusEl.innerText = "⚪ Local Storage Mode";
                kpiStatusEl.style.color = "var(--text-muted)";
            }
        }
    }
};

// Auto-initialize on load
document.addEventListener("DOMContentLoaded", () => {
    GoogleDriveSync.init();
});
