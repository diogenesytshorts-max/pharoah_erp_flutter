let appState = {
    sales: [],
    purchases: [],
    medicines: [
        { id: "1", name: "DOLO 650 MG", batch: "DL-101", exp: "12/28", mrp: 30.91, rate: 28.50, stock: 150, gst: 12 },
        { id: "2", name: "PAN 40 MG", batch: "PN-202", exp: "05/27", mrp: 120.00, rate: 95.00, stock: 80, gst: 12 },
        { id: "3", name: "AZITHRAL 500", batch: "AZ-303", exp: "08/26", mrp: 115.00, rate: 88.00, stock: 45, gst: 12 }
    ],
    parties: [],
    currentCart: []
};

document.addEventListener("DOMContentLoaded", async () => {
    loadLocalData();
    generateNewBillNumber();
    document.getElementById("billDate").value = new Date().toISOString().split('T')[0];
    updateDashboardKpis();

    // Pull fresh data from Drive on start if connected
    if (window.GoogleDriveSync && GoogleDriveSync.config.apiUrl) {
        const cloudData = await GoogleDriveSync.pullFromDrive();
        if (cloudData) {
            Object.assign(appState, cloudData);
            saveLocalData();
            updateDashboardKpis();
        }
    }
});

function switchTab(tabId) {
    document.querySelectorAll("main > section").forEach(sec => sec.style.display = "none");
    document.querySelectorAll(".nav-btn").forEach(btn => btn.classList.remove("active"));
    
    const target = document.getElementById(`tab-${tabId}`);
    if (target) target.style.display = "block";
    
    const activeBtn = Array.from(document.querySelectorAll(".nav-btn")).find(b => b.getAttribute("onclick")?.includes(tabId));
    if (activeBtn) activeBtn.classList.add("active");

    if (tabId === 'ledger') renderLedger();
}

function openGuideModal() { document.getElementById("guideModal").classList.add("active"); }
function closeGuideModal() { document.getElementById("guideModal").classList.remove("active"); }
function openDriveSettings() {
    if (window.GoogleDriveSync) {
        document.getElementById("driveUserEmail").value = GoogleDriveSync.config.userEmail || "";
        document.getElementById("driveApiUrl").value = GoogleDriveSync.config.apiUrl || "";
    }
    document.getElementById("driveSettingsModal").classList.add("active");
}
function closeDriveSettings() { document.getElementById("driveSettingsModal").classList.remove("active"); }

function saveDriveSettingsFromModal() {
    const email = document.getElementById("driveUserEmail").value.trim();
    const url = document.getElementById("driveApiUrl").value.trim();
    if (!url) {
        alert("कृपया Webhook URL भरें!");
        return;
    }
    if (window.GoogleDriveSync) {
        GoogleDriveSync.saveConfig(url, email);
    }
    closeDriveSettings();
    alert("✅ Google Drive सिंक सफलतापूर्वक कनेक्ट हो गया!");
}

function generateNewBillNumber() {
    const randomSeq = Math.floor(1000 + Math.random() * 9000);
    document.getElementById("billNo").value = `WEB-INV-${randomSeq}`;
    appState.currentCart = [];
    renderCart();
}

function addItemToCurrentBill() {
    const name = document.getElementById("itemSearch").value.trim();
    const batch = document.getElementById("itemBatch").value.trim();
    const exp = document.getElementById("itemExp").value.trim();
    const qty = parseFloat(document.getElementById("itemQty").value) || 1;
    const rate = parseFloat(document.getElementById("itemRate").value) || 0;
    const gst = parseFloat(document.getElementById("itemGst").value) || 0;

    if (!name) {
        alert("कृपया आइटम का नाम भरें!");
        return;
    }

    const total = qty * rate * (1 + gst / 100);

    appState.currentCart.push({
        srNo: appState.currentCart.length + 1,
        name, batch, exp, qty, rate, gst, total
    });

    renderCart();
    document.getElementById("itemSearch").value = "";
}

function renderCart() {
    const tbody = document.getElementById("cartTableBody");
    tbody.innerHTML = "";
    let grandTotal = 0;

    appState.currentCart.forEach((item, index) => {
        grandTotal += item.total;
        tbody.innerHTML += `
            <tr>
                <td>${index + 1}</td>
                <td><strong>${item.name}</strong></td>
                <td>${item.batch} (${item.exp})</td>
                <td>${item.qty}</td>
                <td>₹ ${item.rate.toFixed(2)}</td>
                <td>${item.gst}%</td>
                <td><strong>₹ ${item.total.toFixed(2)}</strong></td>
                <td><button class="btn btn-danger" style="padding:4px 8px; font-size:0.7rem;" onclick="removeCartItem(${index})">X</button></td>
            </tr>
        `;
    });

    document.getElementById("billGrandTotal").innerText = `₹ ${grandTotal.toFixed(2)}`;
}

function removeCartItem(index) {
    appState.currentCart.splice(index, 1);
    renderCart();
}

async function saveAndPrintBill(format) {
    if (appState.currentCart.length === 0) {
        alert("बिल खाली है! कृपया पहले आइटम जोड़ें।");
        return;
    }

    const billNo = document.getElementById("billNo").value;
    const billDate = document.getElementById("billDate").value;
    const customer = document.getElementById("customerName").value.trim() || "CASH CUSTOMER";
    const grandTotal = appState.currentCart.reduce((sum, i) => sum + i.total, 0);

    const saleRecord = {
        billNo, billDate, customer,
        items: [...appState.currentCart],
        totalAmount: grandTotal
    };

    appState.sales.push(saleRecord);
    saveLocalData();
    updateDashboardKpis();

    // 2-Way Sync to Drive
    if (window.GoogleDriveSync) {
        GoogleDriveSync.pushToDrive(appState);
    }

    const printArea = document.getElementById("printArea");
    printArea.innerHTML = `
        <div style="padding:20px; font-family:sans-serif;">
            <h2 style="text-align:center;">PHAROAH ERP - TAX INVOICE</h2>
            <p><strong>Invoice:</strong> ${billNo} | <strong>Date:</strong> ${billDate}</p>
            <p><strong>Customer:</strong> ${customer}</p>
            <hr/>
            <table style="width:100%; border-collapse:collapse; margin-top:10px;">
                <thead>
                    <tr style="border-bottom:1px solid #000;">
                        <th>Item</th><th>Batch</th><th>Qty</th><th>Rate</th><th>Total</th>
                    </tr>
                </thead>
                <tbody>
                    ${appState.currentCart.map(i => `
                        <tr>
                            <td>${i.name}</td><td>${i.batch}</td><td>${i.qty}</td><td>₹${i.rate}</td><td>₹${i.total.toFixed(2)}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
            <hr/>
            <h3 style="text-align:right;">GRAND TOTAL: ₹${grandTotal.toFixed(2)}</h3>
        </div>
    `;

    window.print();
    generateNewBillNumber();
    alert("✅ बिल सेव हुआ और Google Drive में सिंक हो गया!");
}

function recordPurchaseEntry() {
    const supplier = document.getElementById("purSupplier").value.trim();
    const billNo = document.getElementById("purBillNo").value.trim();
    const name = document.getElementById("purItemName").value.trim();
    const qty = parseFloat(document.getElementById("purQty").value) || 0;
    const rate = parseFloat(document.getElementById("purRate").value) || 0;

    if (!supplier || !name) {
        alert("कृपया सप्लायर और आइटम का नाम भरें!");
        return;
    }

    const total = qty * rate;
    appState.purchases.push({ supplier, billNo, name, qty, rate, total, date: new Date().toISOString() });
    saveLocalData();
    updateDashboardKpis();

    if (window.GoogleDriveSync) {
        GoogleDriveSync.pushToDrive(appState);
    }

    alert("✅ इनवर्ड स्टॉक सेव हुआ!");
    document.getElementById("purItemName").value = "";
}

function renderLedger() {
    const tbody = document.getElementById("ledgerTableBody");
    const query = document.getElementById("ledgerSearch").value.toLowerCase();
    tbody.innerHTML = "";

    appState.sales.filter(s => s.customer.toLowerCase().includes(query)).forEach(s => {
        tbody.innerHTML += `
            <tr>
                <td>${s.billDate}</td>
                <td><strong>${s.customer}</strong></td>
                <td><span style="color:var(--accent-emerald);">SALE (बिल)</span></td>
                <td>₹ ${s.totalAmount.toFixed(2)}</td>
                <td>-</td>
                <td><strong>₹ ${s.totalAmount.toFixed(2)}</strong></td>
            </tr>
        `;
    });
}

function updateDashboardKpis() {
    const totalSale = appState.sales.reduce((sum, s) => sum + s.totalAmount, 0);
    const totalPur = appState.purchases.reduce((sum, p) => sum + p.total, 0);
    
    document.getElementById("kpi-sale").innerText = `₹ ${totalSale.toFixed(2)}`;
    document.getElementById("kpi-pur").innerText = `₹ ${totalPur.toFixed(2)}`;
    document.getElementById("kpi-stock").innerText = `₹ ${(totalPur - totalSale + 50000).toFixed(2)}`;
}

function saveLocalData() { localStorage.setItem("pharoah_web_state", JSON.stringify(appState)); }
function loadLocalData() {
    const saved = localStorage.getItem("pharoah_web_state");
    if (saved) {
        try { Object.assign(appState, JSON.parse(saved)); } catch(e) {}
    }
}
