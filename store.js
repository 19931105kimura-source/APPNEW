// src/store.js
const fs = require("fs");
const path = require("path");

const { nextOrderId, nextOrderItemId } = require("./ids");
const { TABLE_STATUS, nowIso } = require("./domain");

class Store {
  constructor() {
    this.products = new Map();
    this.tables = new Map();
    this.orders = new Map();
    this.orderItems = new Map();

    this.ordersByTable = new Map();      // tableId -> orderId[]
    this.orderItemsByOrder = new Map();  // orderId -> orderItemId[]

    // ★ RT / UI 用：席注文 snapshot
    this.tableOrders = new Map();        // tableId -> TableOrder

    // ----- menu.json から商品ロード -----
  const nestedMenuPath = path.join(__dirname, "..", "data", "menu.json");
    const rootMenuPath = path.join(__dirname, "menu.json");
    const menuPath = fs.existsSync(nestedMenuPath) ? nestedMenuPath : rootMenuPath;
    const raw = fs.readFileSync(menuPath, "utf-8");
    const menu = JSON.parse(raw);

    for (const item of menu.items) {
      this.products.set(item.productId, item);
    }
  }

  // ---------- Product ----------
  listActiveProducts() {
    return Array.from(this.products.values()).filter(p => p.isActive);
  }

  getProduct(productId) {
    return this.products.get(productId) || null;
  }

  // ---------- Menu Raw (for editor) ----------
  getMenuRawItems() {
    return Array.from(this.products.values());
  }

  // ---------- Table ----------
  openTable(tableId) {
    const existing = this.tables.get(tableId);
    if (existing && existing.status !== TABLE_STATUS.closed) {
      return existing;
    }

    const table = {
      tableId,
      status: TABLE_STATUS.ordering,
      openedAt: nowIso(),
      closedAt: null,
    };

    this.tables.set(tableId, table);
    if (!this.ordersByTable.has(tableId)) {
      this.ordersByTable.set(tableId, []);
    }
    return table;
  }

  getTable(tableId) {
    return this.tables.get(tableId) || null;
  }

  closeTable(tableId) {
    const table = this.tables.get(tableId);
    if (!table) {
      throw new Error(`Table not found: ${tableId}`);
    }
    table.status = TABLE_STATUS.closed;
    table.closedAt = nowIso();
    return table;
  }

  // ---------- Order（確定・印刷用：既存） ----------
  createOrder({ tableId, orderedBy, items }) {
    const table = this.getTable(tableId) || this.openTable(tableId);
    if (table.status === TABLE_STATUS.closed) {
      throw new Error(`Table is closed: ${tableId}`);
    }

    const orderId = nextOrderId();
    const order = {
      orderId,
      tableId,
      orderedAt: nowIso(),
      orderedBy,
      printed: false,
    };

    this.orders.set(orderId, order);

    const orderIds = this.ordersByTable.get(tableId);
    orderIds.push(orderId);

    const orderItemIds = [];

    for (const req of items) {
      const product = this.getProduct(req.productId);
      if (!product || !product.isActive) {
        throw new Error(`Invalid productId: ${req.productId}`);
      }

      const quantity = Number(req.quantity);
      if (!Number.isInteger(quantity) || quantity <= 0) {
        throw new Error(`Invalid quantity for productId=${req.productId}`);
      }
        this.addTableItem(tableId, {
    productId: product.productId,
    qty: quantity,
    addedBy: orderedBy,
  });
      const orderItemId = nextOrderItemId();
      const orderItem = {
        orderItemId,
        orderId,
        productId: product.productId,
        name: product.name,
        price: product.price,
        quantity,
        printTarget: product.printTarget || "none",
        printed: {
          drink: false,
          food: false,
        },
      };

      this.orderItems.set(orderItemId, orderItem);
      orderItemIds.push(orderItemId);
    }

    this.orderItemsByOrder.set(orderId, orderItemIds);

    return {
      order,
      orderItems: orderItemIds.map(id => this.orderItems.get(id)),
    };
  }

  markOrderPrinted(orderId) {
    const order = this.orders.get(orderId);
    if (!order) {
      throw new Error(`Order not found: ${orderId}`);
    }
    order.printed = true;
    return order;
  }

  // ---------- Snapshot（既存・会計用） ----------
  getTableSnapshot(tableId) {
    const table = this.getTable(tableId);
    if (!table) return null;

    const orderIds = this.ordersByTable.get(tableId) || [];
    const orders = orderIds.map(id => this.orders.get(id)).filter(Boolean);

    const orderItems = [];
    for (const order of orders) {
      const itemIds = this.orderItemsByOrder.get(order.orderId) || [];
      for (const itemId of itemIds) {
        const item = this.orderItems.get(itemId);
        if (item) orderItems.push(item);
      }
    }

    return { table, orders, orderItems };
  }
getTableItems(tableId) {
    const orderIds = this.ordersByTable.get(tableId) || [];
    const items = [];

    for (const orderId of orderIds) {
      const itemIds = this.orderItemsByOrder.get(orderId) || [];

      for (const itemId of itemIds) {
        const item = this.orderItems.get(itemId);
        if (!item) continue;

        items.push({
          ...item,
          quantity: Number(item.quantity ?? item.qty ?? 0),
          qty: Number(item.qty ?? item.quantity ?? 0),
        });
      }
    }

    return items;
  }

  // ---------- Checkout ----------
  calcCheckout(tableId) {
    const snap = this.getTableSnapshot(tableId);
    if (!snap) {
      throw new Error(`Table not found: ${tableId}`);
    }

    const lines = new Map();

    for (const item of snap.orderItems) {
      const cur = lines.get(item.productId) || {
        productId: item.productId,
        name: item.name,
        price: item.price,
        quantity: 0,
        amount: 0,
      };
      cur.quantity += item.quantity;
      cur.amount += item.price * item.quantity;
      lines.set(item.productId, cur);
    }

    const details = Array.from(lines.values());
    const total = details.reduce((sum, d) => sum + d.amount, 0);

    return {
      tableId,
      openedAt: snap.table.openedAt,
      details,
      total,
    };
  }

  // ---------- Print Data Builder ----------
  buildPrintJobs(orderId) {
    const order = this.orders.get(orderId);
    if (!order) {
      throw new Error(`Order not found: ${orderId}`);
    }

    const itemIds = this.orderItemsByOrder.get(orderId) || [];
    const items = itemIds
      .map(id => this.orderItems.get(id))
      .filter(Boolean);

    const jobs = {
      drink: [],
      food: [],
    };

    for (const item of items) {
      if (item.printTarget === "drink") {
        jobs.drink.push(item);
      } else if (item.printTarget === "food") {
        jobs.food.push(item);
      }
    }

    return {
      orderId,
      tableId: order.tableId,
      orderedAt: order.orderedAt,
      jobs,
    };
  }

  // ==================================================
  // ===== Table Order Snapshot（RT / UI 用・新規）=====
  // ==================================================

  _makeLineId() {
    return "l_" + Math.random().toString(36).slice(2, 10);
  }

  getTableOrderSnapshot(tableId) {
    const key = String(tableId);
    let snap = this.tableOrders.get(key);

    if (!snap) {
      snap = {
        tableId: key,
        openedAt: nowIso(),
        items: [],
      };
      this.tableOrders.set(key, snap);
    }
    return snap;
  }

    addTableItem(tableId, { productId, qty, addedBy }){
    const product = this.getProduct(productId);
    if (!product || !product.isActive) {
      throw new Error(`Invalid productId: ${productId}`);
    }

    const quantity = Number(qty);
    if (!Number.isInteger(quantity) || quantity <= 0) {
      throw new Error("Invalid qty");
    }

    const snap = this.getTableOrderSnapshot(tableId);

    const line = {
      lineId: this._makeLineId(),
      productId: product.productId,
      name: product.name,
      price: product.price,
      qty: quantity,
      addedBy: addedBy === "owner" ? "owner" : "guest",
    };

    snap.items.push(line);
    return line;
  }

 addTableItemSnapshot(tableId, { name, label, brand, category, section, subCategory, printGroup, price, qty, addedBy }) {
    const quantity = Number(qty);
    if (!Number.isInteger(quantity) || quantity <= 0) {
      throw new Error("Invalid qty");
    }

    const snap = this.getTableOrderSnapshot(tableId);
    const normalized = {
      productId: null,
      name: name ?? "",
      label: label ?? "",
      brand: brand ?? "",
      category: category ?? "",
      section: section ?? null,
      subCategory: subCategory ?? "",
      printGroup: printGroup ?? "kitchen",
      price: Number(price) || 0,
      addedBy: addedBy === "owner" ? "owner" : "guest",
    };

    const existing = snap.items.find((item) =>
      item.productId == null &&
      String(item.name ?? "") === normalized.name &&
      String(item.label ?? "") === normalized.label &&
      String(item.brand ?? "") === normalized.brand &&
      String(item.category ?? "") === normalized.category &&
      String(item.section ?? "") === String(normalized.section ?? "") &&
      String(item.subCategory ?? "") === normalized.subCategory &&
      String(item.printGroup ?? "") === normalized.printGroup &&
      Number(item.price ?? 0) === normalized.price &&
      String(item.addedBy ?? "") === normalized.addedBy,
    );

    if (existing) {
      existing.qty = Number(existing.qty ?? 0) + quantity;
      return existing;
    }

    const line = {
      lineId: this._makeLineId(),
      ...normalized,
      qty: quantity,
    };

    snap.items.push(line);
    return line;
  }

  

  updateTableItemQty(tableId, lineId, qty) {
    const snap = this.getTableOrderSnapshot(tableId);
    const q = Number(qty);

    if (!Number.isInteger(q) || q <= 0) {
      throw new Error("Invalid qty");
    }

    const item = snap.items.find(i => i.lineId === String(lineId));
    if (!item) {
      throw new Error("Line not found");
    }

    item.qty = q;
    return item;
  }

  removeTableItem(tableId, lineId) {
    const snap = this.getTableOrderSnapshot(tableId);
    const before = snap.items.length;

    snap.items = snap.items.filter(i => i.lineId !== String(lineId));

    if (before === snap.items.length) {
      throw new Error("Line not found");
    }
  }

 removeTableItemsByNamePrice(tableId, name, price) {
    const snap = this.getTableOrderSnapshot(tableId);
    const targetName = String(name ?? "");
    const targetPrice = Number(price ?? 0);
    const before = snap.items.length;

    snap.items = snap.items.filter(
      i =>
        String(i.name ?? "") !== targetName ||
        Number(i.price ?? 0) !== targetPrice,
    );

    if (before === snap.items.length) {
      throw new Error("Line not found");
    }

    
   return before - snap.items.length;
  }

  _mergeSnapshotItems(baseItems, addItems) {
    const merged = [...baseItems.map(item => ({ ...item }))];
    for (const item of addItems) {
      const key = `${item.productId ?? ""}|${item.name ?? ""}|${item.price ?? 0}|${item.addedBy ?? ""}`;
      const target = merged.find(
        m =>
          `${m.productId ?? ""}|${m.name ?? ""}|${m.price ?? 0}|${m.addedBy ?? ""}` === key,
      );
      if (target) {
        target.qty += item.qty ?? 0;
      } else {
        merged.push({ ...item });
      }
    }
    return merged;
  }

  moveTableOrderSnapshot(from, to) {
    const fromKey = String(from);
    const toKey = String(to);
    if (fromKey === toKey) return;

    const fromTable = this.tables.get(fromKey);
    if (!fromTable) {
      throw new Error(`Table not found: ${fromKey}`);
    }

    const toSnap = this.tableOrders.get(toKey);
    if (toSnap && toSnap.items && toSnap.items.length > 0) {
      throw new Error(`Target table already has items: ${toKey}`);
    }

    const toOrderIds = this.ordersByTable.get(toKey);
    if (toOrderIds && toOrderIds.length > 0) {
      throw new Error(`Target table already has orders: ${toKey}`);
    }

    const fromSnap = this.getTableOrderSnapshot(fromKey);
    this.tableOrders.set(toKey, {
      tableId: toKey,
      openedAt: fromSnap.openedAt,
      items: [...fromSnap.items],
    });
    this.tableOrders.delete(fromKey);

    const fromOrderIds = this.ordersByTable.get(fromKey);
    if (fromOrderIds && fromOrderIds.length > 0) {
      this.ordersByTable.set(toKey, [...fromOrderIds]);
      this.ordersByTable.delete(fromKey);
      for (const orderId of fromOrderIds) {
        const order = this.orders.get(orderId);
        if (order) order.tableId = toKey;
      }
    } else if (!this.ordersByTable.has(toKey)) {
      this.ordersByTable.set(toKey, []);
    }

    this.tables.set(toKey, {
      tableId: toKey,
      status: TABLE_STATUS.ordering,
      openedAt: fromTable.openedAt,
      closedAt: null,
    });
    fromTable.status = TABLE_STATUS.closed;
    fromTable.closedAt = nowIso();
  }

  mergeTableOrderSnapshot(from, to) {
    const fromKey = String(from);
    const toKey = String(to);
    if (fromKey === toKey) return;

    const fromTable = this.tables.get(fromKey);
    if (!fromTable) {
      throw new Error(`Table not found: ${fromKey}`);
    }

    const fromSnap = this.getTableOrderSnapshot(fromKey);
    const toSnap = this.getTableOrderSnapshot(toKey);
    toSnap.items = this._mergeSnapshotItems(toSnap.items, fromSnap.items);

    const fromOrderIds = this.ordersByTable.get(fromKey) ?? [];
    const toOrderIds = this.ordersByTable.get(toKey) ?? [];
    if (fromOrderIds.length > 0) {
      const mergedIds = [...toOrderIds, ...fromOrderIds];
      this.ordersByTable.set(toKey, mergedIds);
      this.ordersByTable.delete(fromKey);
      for (const orderId of fromOrderIds) {
        const order = this.orders.get(orderId);
        if (order) order.tableId = toKey;
      }
    } else if (!this.ordersByTable.has(toKey)) {
      this.ordersByTable.set(toKey, [...toOrderIds]);
    }

    const toTable = this.tables.get(toKey);
    if (toTable) {
      toTable.status = TABLE_STATUS.ordering;
      toTable.closedAt = null;
    } else {
      this.tables.set(toKey, {
        tableId: toKey,
        status: TABLE_STATUS.ordering,
        openedAt: fromTable.openedAt,
        closedAt: null,
      });
    }

    this.tableOrders.delete(fromKey);
    fromTable.status = TABLE_STATUS.closed;
    fromTable.closedAt = nowIso();
  }
  buildRealtimeSnapshot() {
    const tables = {};
    const ordersByTable = {};
    const orderItems = {};

    // ★ 追加：tables（使用中/closed 等）を正本として全席を流す
    for (const [tableId, table] of this.tables.entries()) {
      const order = this.tableOrders.get(tableId) ?? {
        tableId,
        openedAt: table.openedAt,
        items: [],
      };

      tables[tableId] = {
        tableId,
        status: table.status, // ★ ordering / closed
        openedAt: table.openedAt,
        order, // ★ 注文スナップショット（items）
      };

      const rtOrderId = `rt_${tableId}`;
      ordersByTable[tableId] = [rtOrderId];
      orderItems[rtOrderId] = (order.items || []).map((item) => ({
        lineId: item.lineId,
       category: item.category ?? "",
        brand: item.brand ?? "",
        name: item.name ?? "",
         label: item.label ?? item.name ?? "",
        price: item.price ?? 0,
        qty: item.qty ?? 0,
        quantity: item.qty ?? 0,
         section: item.section ?? null,
        subCategory: item.subCategory ?? "",
        shouldPrint: true,
        printGroup: item.printGroup ?? "kitchen",
      }));
    }

    return {
      tables,
      ordersByTable,
      orderItems,
      at: nowIso(),
    };
  }
}
const store = new Store();
module.exports = { store };