// =============================================================================
// PHAROAH ERP - CORE BUSINESS LOGIC ENGINE (MIRROR OF FLUTTER PharoahManager)
// =============================================================================

class PharoahWebEngine {
    constructor() {
        this.medicines = [];
        this.parties = [];
        this.companies = [];
        this.salts = [];
        this.sales = [];
        this.purchases = [];
        this.saleChallans = [];
        this.purchaseChallans = [];
        this.saleReturns = [];
        this.purchaseReturns = [];
        this.vouchers = [];
        this.batchHistory = {}; // Key: medicine.systemId -> List of Batches
        this.numberingSeries = [
            { id: 's_sale', type: 'SALE', prefix: 'INV-', startNumber: 1001, isDefault: true, isActive: true },
            { id: 's_pur', type: 'PURCHASE', prefix: 'PUR-', startNumber: 101, isDefault: true, isActive: true },
            { id: 's_sch', type: 'CHALLAN', prefix: 'SCH-', startNumber: 101, isDefault: true, isActive: true },
            { id: 's_ret', type: 'RETURN', prefix: 'CN-', startNumber: 101, isDefault: true, isActive: true },
            { id: 's_rct', type: 'RECEIPT', prefix: 'RCT-', startNumber: 101, isDefault: true, isActive: true },
            { id: 's_pay', type: 'PAYMENT', prefix: 'PAY-', startNumber: 101, isDefault: true, isActive: true }
        ];
        this.initDemoData();
    }

    initDemoData() {
        this.medicines = [
            { id: "PH-10001", systemId: "PH-10001", name: "DOLO 650 MG", packing: "15 TAB", hsnCode: "3004", gst: 12, mrp: 30.91, purRate: 25.40, rateA: 28.50, rateB: 27.00, rateC: 26.50, stock: 150, drugForm: "TAB", isNarcotic: false, isScheduleH1: false },
            { id: "PH-10002", systemId: "PH-10002", name: "PAN 40 MG", packing: "10 TAB", hsnCode: "3004", gst: 12, mrp: 120.00, purRate: 95.00, rateA: 110.00, rateB: 105.00, rateC: 100.00, stock: 80, drugForm: "TAB", isNarcotic: false, isScheduleH1: false },
            { id: "PH-10003", systemId: "PH-10003", name: "AZITHRAL 500", packing: "5 TAB", hsnCode: "3004", gst: 12, mrp: 115.00, purRate: 88.00, rateA: 105.00, rateB: 100.00, rateC: 98.00, stock: 45, drugForm: "TAB", isNarcotic: false, isScheduleH1: false }
        ];

        this.parties = [
            { id: "p_cash", name: "CASH CUSTOMER", group: "Cash in Hand", city: "LOCAL", state: "Rajasthan", phone: "", gst: "", dl: "", opBal: 0.0 },
            { id: "p_101", name: "SHARMA MEDICALS", group: "Sundry Debtors", city: "JAIPUR", state: "Rajasthan", phone: "9876543210", gst: "08ABCDE1234F1Z5", dl: "DL-20B-101", opBal: 4500.0 },
            { id: "p_102", name: "ABC PHARMA DISTRIBUTORS", group: "Sundry Creditors", city: "UDAIPUR", state: "Rajasthan", phone: "9123456780", gst: "08FSBPM0623R1ZC", dl: "DL-21B-202", opBal: -12000.0 }
        ];

        this.batchHistory = {
            "PH-10001": [{ batch: "DL-101", exp: "12/28", packing: "15 TAB", mrp: 30.91, rate: 25.40, rateA: 28.50, rateB: 27.00, rateC: 26.50, qty: 150, openingQty: 150, adjustmentQty: 0 }],
            "PH-10002": [{ batch: "PN-202", exp: "05/27", packing: "10 TAB", mrp: 120.00, rate: 95.00, rateA: 110.00, rateB: 105.00, rateC: 100.00, qty: 80, openingQty: 80, adjustmentQty: 0 }],
            "PH-10003": [{ batch: "AZ-303", exp: "08/26", packing: "5 TAB", mrp: 115.00, rate: 88.00, rateA: 105.00, rateB: 100.00, rateC: 98.00, qty: 45, openingQty: 45, adjustmentQty: 0 }]
        };
    }

    // =========================================================================
    // 1. DYNAMIC INVENTORY REBUILD ENGINE (FLUTTER PARITY)
    // =========================================================================
    rebuildAllInventory() {
        // Reset batches to base opening + adjustments
        Object.keys(this.batchHistory).forEach(key => {
            this.batchHistory[key].forEach(b => {
                b.qty = (b.openingQty || 0) + (b.adjustmentQty || 0);
            });
        });

        // Purchases (Stock IN +)
        this.purchases.forEach(p => {
            p.items.forEach(it => {
                this._applyStock(it.medicineID, it.name, it.batch, it.exp, it.packing, it.mrp, it.purchaseRate, (it.qty + it.freeQty), true);
            });
        });

        // Sales (Stock OUT -)
        this.sales.filter(s => s.status === 'Active').forEach(s => {
            s.items.forEach(it => {
                this._applyStock(it.medicineID, it.name, it.batch, it.exp, it.packing, it.mrp, it.rate, (it.qty + it.freeQty), false);
            });
        });

        // Sellable Sales Returns (Stock IN +)
        this.saleReturns.filter(r => r.status === 'Active' && r.returnType === 'Sellable').forEach(r => {
            r.items.forEach(it => {
                this._applyStock(it.medicineID, it.name, it.batch, it.exp, it.packing, it.mrp, it.rate, (it.qty + it.freeQty), true);
            });
        });

        // Purchase Returns (Stock OUT -)
        this.purchaseReturns.filter(r => r.status === 'Active').forEach(r => {
            r.items.forEach(it => {
                this._applyStock(it.medicineID, it.name, it.batch, it.exp, it.packing, it.mrp, it.purchaseRate, (it.qty + it.freeQty), false);
            });
        });

        // Sync parent medicine stock
        this.medicines.forEach(m => {
            const key = m.systemId || m.id;
            if (this.batchHistory[key]) {
                m.stock = this.batchHistory[key].reduce((sum, b) => sum + (b.qty || 0), 0);
            }
        });
    }

    _applyStock(medId, medName, batchNo, exp, packing, mrp, rate, qty, isAdd) {
        const med = this.medicines.find(m => m.id === medId || m.systemId === medId || m.name.toUpperCase() === medName.toUpperCase());
        if (!med) return;
        const key = med.systemId || med.id;

        if (!this.batchHistory[key]) this.batchHistory[key] = [];
        let batch = this.batchHistory[key].find(b => b.batch.trim().toUpperCase() === batchNo.trim().toUpperCase());

        if (batch) {
            batch.qty += isAdd ? qty : -qty;
        } else if (isAdd) {
            this.batchHistory[key].push({
                batch: batchNo.trim(),
                exp: exp || "12/28",
                packing: packing || med.packing,
                mrp: mrp || med.mrp,
                rate: rate || med.purRate,
                rateA: med.rateA,
                rateB: med.rateB,
                rateC: med.rateC,
                qty: qty,
                openingQty: 0,
                adjustmentQty: 0
            });
        }
    }

    // =========================================================================
    // 2. MASTER USAGE INTEGRITY LOCKS (CANNOT DELETE IN-USE RECORDS)
    // =========================================================================
    isPartyInUse(partyId, partyName) {
        const pId = partyId;
        const pName = partyName.toUpperCase();

        const inSales = this.sales.some(s => s.partyId === pId || s.partyName.toUpperCase() === pName);
        const inPurchases = this.purchases.some(p => p.partyId === pId || p.distributorName.toUpperCase() === pName);
        const inVouchers = this.vouchers.some(v => v.partyId === pId || v.partyName.toUpperCase() === pName);
        const inChallans = this.saleChallans.some(c => c.partyName.toUpperCase() === pName);
        const inReturns = this.saleReturns.some(r => r.partyName.toUpperCase() === pName) || this.purchaseReturns.some(r => r.distributorName.toUpperCase() === pName);

        return inSales || inPurchases || inVouchers || inChallans || inReturns;
    }

    isProductInUse(medId) {
        const inSales = this.sales.some(s => s.items.some(it => it.medicineID === medId));
        const inPurchases = this.purchases.some(p => p.items.some(it => it.medicineID === medId));
        return inSales || inPurchases;
    }

    // =========================================================================
    // 3. NUMBERING ENGINE & NEXT ID GENERATOR
    // =========================================================================
    getNextNumber(type) {
        const series = this.numberingSeries.find(s => s.type === type && s.isDefault) || { prefix: 'DOC-', startNumber: 1001 };
        let list = [];

        if (type === 'SALE') list = this.sales.map(s => s.billNo);
        else if (type === 'PURCHASE') list = this.purchases.map(p => p.internalNo);
        else if (type === 'CHALLAN') list = this.saleChallans.map(c => c.billNo);
        else if (type === 'RETURN') list = this.saleReturns.map(r => r.billNo);
        else if (type === 'RECEIPT' || type === 'PAYMENT') list = this.vouchers.filter(v => v.type === type).map(v => v.voucherNo);

        const existingNums = list
            .filter(no => no && no.startsWith(series.prefix))
            .map(no => parseInt(no.replace(series.prefix, '')) || 0);

        if (existingNums.length === 0) return `${series.prefix}${series.startNumber}`;
        const maxNo = Math.max(...existingNums);
        return `${series.prefix}${maxNo + 1}`;
    }

    // =========================================================================
    // 4. TRANSACTION HISTORY & PENDING BILLS (FOR VOUCHERS & RETURNS)
    // =========================================================================
    getPendingBills(partyName, isReceipt) {
        let pending = [];
        if (isReceipt) {
            this.sales.filter(s => s.partyName.toUpperCase() === partyName.toUpperCase() && s.paymentMode === 'CREDIT' && s.status === 'Active').forEach(s => {
                const isSettled = this.vouchers.some(v => v.status === 'Active' && v.linkedBillNumbers && v.linkedBillNumbers.includes(s.billNo));
                if (!isSettled) pending.push({ billNo: s.billNo, date: s.date, amount: s.totalAmount });
            });
        }
        return pending;
    }

    getMedicineHistory(partyName, medId) {
        let history = [];
        this.sales.filter(s => s.partyName.toUpperCase() === partyName.toUpperCase() && s.status === 'Active').forEach(s => {
            s.items.filter(it => it.medicineID === medId).forEach(it => {
                history.push({ billNo: s.billNo, date: s.date, batch: it.batch, exp: it.exp, qty: it.qty, free: it.freeQty, rate: it.rate, mrp: it.mrp });
            });
        });
        return history;
    }
}

// Global Engine Instance
window.erpEngine = new PharoahWebEngine();
