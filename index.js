const express = require("express");
const path = require("path");
const fs = require("fs");
const multer = require("multer");
const http = require("http");
const WebSocket = require("ws");

const { store } = require("./src/store");
const { enqueuePrint } = require("./src/printer");
const printTextWindows = enqueuePrint; // 互換: 旧呼び出し箇所が残っていても落ちないようにする
const { buildReceiptText } = require("./src/domain");

const app = express();
function resolveDataPath(fileName) {
  const nested = path.join(__dirname, "data", fileName);
  const root = path.join(__dirname, fileName);
  return fs.existsSync(nested) ? nested : root;
}

const MENU_PATH = resolveDataPath("menu.json");
const PRINTER_SETTINGS_PATH = resolveDataPath("printer_settings.json");

function readPrinterSettings() {
  if (!fs.existsSync(PRINTER_SETTINGS_PATH)) {
    return {
      kitchen: { host: "", port: 9100 },
      register: { host: "", port: 9100 },
      receipt: { host: "", port: 9100 },
    };
  }

  try {
    const raw = JSON.parse(fs.readFileSync(PRINTER_SETTINGS_PATH, "utf8"));
    return {
      kitchen: {
        host: String(raw?.kitchen?.host ?? "").trim(),
        port: Number(raw?.kitchen?.port) || 9100,
      },
      register: {
        host: String(raw?.register?.host ?? "").trim(),
        port: Number(raw?.register?.port) || 9100,
      },
      receipt: {
        host: String(raw?.receipt?.host ?? "").trim(),
        port: Number(raw?.receipt?.port) || 9100,
      },
    };
  } catch (e) {
    console.error("PRINTER SETTINGS LOAD ERROR:", e);
    return {
      kitchen: { host: "", port: 9100 },
      register: { host: "", port: 9100 },
      receipt: { host: "", port: 9100 },
    };
  }
}

function applyPrinterSettingsToEnv(settings) {
  for (const target of ["kitchen", "register", "receipt"]) {
    const host = String(settings?.[target]?.host ?? "").trim();
    const port = Number(settings?.[target]?.port) || 9100;
    const key = target.toUpperCase();

    if (host) {
      process.env[`PRINTER_${key}_HOST`] = host;
    }
    process.env[`PRINTER_${key}_PORT`] = String(port);
  }
}

function savePrinterSettings(settings) {
  fs.writeFileSync(
    PRINTER_SETTINGS_PATH,
    JSON.stringify({ updatedAt: new Date().toISOString(), ...settings }, null, 2),
  );
}

applyPrinterSettingsToEnv(readPrinterSettings());



// requestId 冪等化（重複注文防止）
const processedOrderRequests = new Map(); // requestId -> response payload
const REQUEST_TTL_MS = 1000 * 60 * 30;

function rememberOrderRequest(requestId, payload) {
  processedOrderRequests.set(requestId, {
    payload,
    expiresAt: Date.now() + REQUEST_TTL_MS,
  });
}

function getRememberedOrderRequest(requestId) {
  const e = processedOrderRequests.get(requestId);
  if (!e) return null;
  if (e.expiresAt < Date.now()) {
    processedOrderRequests.delete(requestId);
    return null;
  }
  return e.payload;
}

setInterval(() => {
  const now = Date.now();
  for (const [key, value] of processedOrderRequests.entries()) {
    if (value.expiresAt < now) processedOrderRequests.delete(key);
  }
}, 60 * 1000);

// =========================
// アップロード（宣材）設定
// =========================
const uploadDir = path.join(__dirname, "uploads", "promos");

// ★ 必ずフォルダを作る（初回 ENOENT 対策）
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const name = `promo_${Date.now()}${ext}`;
    cb(null, name);
  },
});

// ★ upload は route より前に定義（ReferenceError 対策）
const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB（動画OK）
});

// =========================
// Middleware
// =========================
app.use(express.json());

// order API の到達確認ログ（原因切り分け用）
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// JSON パース失敗時の診断ログ
app.use((err, req, res, next) => {
  if (err && err instanceof SyntaxError && "body" in err) {
    console.error("JSON PARSE ERROR", {
      path: req.path,
      message: err.message,
    });
    return res.status(400).json({
      ok: false,
      success: false,
      error: "invalid json",
      details: [err.message],
    });
  }
  next(err);
});
app.use(express.static(path.join(__dirname, "public")));

// uploads を静的配信（/uploads/promos/xxx で見える）
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// ===== CORS許可（ローカル用）=====
app.use((req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader(
  "Access-Control-Allow-Methods",
  "GET,POST,PATCH,DELETE,OPTIONS"
);

  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  next();
});

// =========================
// 共通：menu productId 安定化
// =========================
function makeKey(item) {
  return `${item.category}::${item.name}::${item.variantLabel}`;
}

function loadExistingMap() {
  if (!fs.existsSync(MENU_PATH)) return new Map();

  const json = JSON.parse(fs.readFileSync(MENU_PATH, "utf8"));
  const map = new Map();

  for (const it of json.items || []) {
    map.set(makeKey(it), it.productId);
  }
  return map;
}

// -------------------------
// 共通：テーブルの注文明細取得 / オーダー表印刷
// -------------------------
function normalizePrintTarget(value) {
  const raw = String(value ?? "").toLowerCase();
  if (raw === "none" || raw === "off" || raw === "false") return "none";
  if (raw === "register" || raw === "food") return "register";
  if (raw === "kitchen" || raw === "drink") return "kitchen";
  return "kitchen";
}

function readIntEnv(name, fallback) {
  const n = Number(process.env[name]);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : fallback;
}

function isWideChar(char) {
  return /[\u1100-\u115F\u2E80-\uA4CF\uAC00-\uD7A3\uF900-\uFAFF\uFE10-\uFE19\uFE30-\uFE6F\uFF01-\uFF60\uFFE0-\uFFE6]/.test(
    char
  );
}

function stringDisplayWidth(value) {
  return Array.from(String(value ?? "")).reduce(
    (sum, char) => sum + (isWideChar(char) ? 2 : 1),
    0
  );
}

function padDisplayEnd(value, width) {
  const text = String(value ?? "");
  const current = stringDisplayWidth(text);
  if (current >= width) return text;
  return text + " ".repeat(width - current);
}

function padDisplayStart(value, width) {
  const text = String(value ?? "");
  const current = stringDisplayWidth(text);
  if (current >= width) return text;
  return " ".repeat(width - current) + text;
}

function makeRuleLine(name, fallbackWidth = 20, fallbackChar = "─") {
  const width = readIntEnv(name, fallbackWidth);
  const char = process.env[`${name}_CHAR`] || fallbackChar;
  return char.repeat(width);
}

function isCastDrinkItem(item) {
  return String(item?.category ?? "").trim() === "キャストドリンク";
}

function printableItemName(item) {
  const baseName = String(item?.name ?? "").trim();
  const castName = String(item?.brand ?? "").trim();
  const fallback = item?.brand && item?.label
    ? `${item.brand} / ${item.label}`
    : String(item?.label ?? "").trim() || "unknown";
  const name = baseName || fallback;

  if (!isCastDrinkItem(item) || !castName) {
    return name;
  }

  if (name.includes(castName)) {
    return name;
  }

  return `${name}（${castName}）`;
}

function shortenReceiptDrinkName(rawName) {
  const name = String(rawName ?? "").trim();
  if (!name) return "unknown";

  // 先頭2文字で省略表示
  return Array.from(name).slice(0, 2).join("") || name;
}

function printableReceiptItemName(item) {
  if (isCastDrinkItem(item)) {
    const castName = String(item?.brand ?? "").trim();
    const rawDrinkName = String(item?.label ?? "").trim() || String(item?.name ?? "").trim();
    const drinkName = shortenReceiptDrinkName(rawDrinkName);

    if (!castName) {
      return drinkName;
    }

    return `${drinkName}（${castName}）`;
 }

  const labelName = String(item?.label ?? "").trim();
  const itemName = String(item?.name ?? "").trim();

  // 会計伝票では、キャストドリンク以外はブランド名を印字しない
  // 「商品名（label）」があればそれだけを使う
  if (labelName) {
    return labelName;
  }

  if (itemName) {
    return itemName;
  }

  return printableItemName(item);
}
/////////オーダー伝票表示位置////////////
function buildOrderSlipText({ tableId, target, items }) {
  const ruleLine = makeRuleLine("ORDER_SLIP_RULE_WIDTH");////罫線の長さ
  const nameWidth = readIntEnv("ORDER_SLIP_NAME_WIDTH", 14);////品名幅
  const qtyWidth = readIntEnv("ORDER_SLIP_QTY_WIDTH", 4);/////数量幅
  const titleIndent = readIntEnv("ORDER_SLIP_TITLE_INDENT", 7);/////タイトルのインデント（スペース数）

  const lines = [];
  const targetLabel = target === "register" ? "レジ" : "厨房";

  lines.push(ruleLine);
  lines.push(`${" ".repeat(titleIndent)}注 文 票（${targetLabel}）`);
  lines.push(ruleLine);
  lines.push(`席：${tableId}`);
  lines.push("");
   // ↓ この部分が丸ごと抜けていた
  for (const item of items) {
    const name = printableItemName(item);
    const qty = Number(item.quantity ?? item.qty ?? 1);
    const namePart = padDisplayEnd(name, nameWidth);
    const qtyPart = padDisplayStart(qty, qtyWidth);
    lines.push(`${namePart}${qtyPart}`);
}
 lines.push("");
  return lines.join("\n");
}
async function printOrderSlip({ tableId, target, items }) {
  const normalizedTarget = normalizePrintTarget(target);
  const sourceItems = Array.isArray(items) ? items : getTableItems(tableId);
  const printableItems = sourceItems.filter((item) => {
    if (item.shouldPrint === false) return false;
    const itemTarget = normalizePrintTarget(item.printGroup ?? item.printTarget);
    return itemTarget === normalizedTarget && itemTarget !== "none" && Number(item.quantity ?? 0) > 0;
  });

  if (printableItems.length === 0) {
    return { printed: 0, target: normalizedTarget };
  }

  const text = buildOrderSlipText({
    tableId,
    target: normalizedTarget,
    items: printableItems,
  });

  await enqueuePrint([{ type: "text", text }], normalizedTarget);
  return { printed: printableItems.length, target: normalizedTarget };
}


// -------------------------
// 共通：会計計算
// -------------------------
function floorToTenYen(value) {
  return Math.floor(Number(value || 0) / 100) * 100;
}
function getTableItems(tableId) {
  const orderIds = store.ordersByTable.get(tableId) || [];
  const result = [];

  for (const orderId of orderIds) {
    const itemIds = store.orderItemsByOrder.get(orderId) || [];
    for (const itemId of itemIds) {
      const item = store.orderItems.get(itemId);
      if (item) result.push(item);
    }
  }

  return result;
}
function calcReceiptSummary(tableId) {
  const items = getTableItems(tableId);

  let taxableSubtotal = 0;
  let nonTaxableSubtotal = 0;

  for (const item of items) {
    const lineTotal = item.price * item.quantity;
    const isAnnaiSet =
      String(item?.category ?? "").trim() === "セット" &&
      String(item?.brand ?? "").trim() === "案内所";

    if (isAnnaiSet) {
      nonTaxableSubtotal += lineTotal;
    } else {
      taxableSubtotal += lineTotal;
    }
  }

  const taxIncludedAmount = Math.floor(taxableSubtotal * 1.10);
  const serviceIncludedAmount = Math.floor(taxIncludedAmount * 1.25);
  const grossTotal = serviceIncludedAmount + nonTaxableSubtotal;
  const total = floorToTenYen(grossTotal);

  return {
    items,
    taxableSubtotal,
    nonTaxableSubtotal,
    tax: taxIncludedAmount - taxableSubtotal,
    service: serviceIncludedAmount - taxIncludedAmount,
    total,
  };
}

// =========================
// API
// =========================

// --------------------
// 宣材ファイルアップロード（画像/動画）
// --------------------
app.post("/api/upload/promo", upload.single("file"), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "file not found" });
  }

  // Flutter にはこのURLを返す（Webで見えるパス）
  const url = `/uploads/promos/${req.file.filename}`;
  res.json({ url });
});

// --------------------
// メニュー取得（編集用・原本）
// --------------------
app.get("/api/menu", (req, res) => {
  try {
    const items = store.getMenuRawItems();
    res.json(items);
  } catch (e) {
    console.error("MENU LOAD ERROR:", e);
    res.status(500).json({ error: "failed to load menu" });
  }
});

// --------------------
// メニュー保存（productId 安定化）
// --------------------
app.post("/api/menu", (req, res) => {
  console.log("POST /api/menu received");
  console.log("items length =", req.body.items?.length);

  const { items } = req.body;
  if (!Array.isArray(items)) {
    return res.status(400).json({ error: "items is required" });
  }

  const existing = loadExistingMap();

  let nextId = 1;
  for (const pid of existing.values()) {
    const n = Number(String(pid).replace("p_", ""));
    if (!isNaN(n)) nextId = Math.max(nextId, n + 1);
  }

  const stabilized = items.map((it) => {
    const key = makeKey(it);
    let productId = existing.get(key);
    if (!productId) productId = `p_${nextId++}`;
    return { ...it, productId };
  });

  fs.writeFileSync(
    MENU_PATH,
    JSON.stringify({ version: 2, updatedAt: new Date(), items: stabilized }, null, 2)
  );

  store.products.clear();
  for (const it of stabilized) {
    store.products.set(it.productId, it);
  }

  res.json({ success: true });
});


function replaceTableItems(tableId, rawLines) {
  const existingOrderIds = store.ordersByTable.get(tableId) || [];
  for (const orderId of existingOrderIds) {
    const ids = store.orderItemsByOrder.get(orderId) || [];
    for (const itemId of ids) {
      store.orderItems.delete(itemId);
    }
    store.orderItemsByOrder.delete(orderId);
  }

  store.ordersByTable.set(tableId, []);

  if (!Array.isArray(rawLines) || rawLines.length === 0) {
    return { orderId: null, itemCount: 0 };
  }

  const orderId = `order_sync_${Date.now()}`;
  store.ordersByTable.set(tableId, [orderId]);

  const itemIds = [];
  rawLines.forEach((it, idx) => {
    const itemId = `item_sync_${Date.now()}_${idx}`;
    const quantity = Number(it.qty ?? it.quantity ?? 0);
    if (!Number.isFinite(quantity) || quantity <= 0) return;

    const price = Number(it.price ?? 0);
    const printTarget = it.printTarget ?? 'drink';
    const printGroup = normalizePrintTarget(it.printGroup ?? printTarget);
    const name = it.name ?? (it.brand && it.label ? `${it.brand} / ${it.label}` : (it.label ?? 'unknown'));

    const normalized = {
      id: itemId,
      orderId,
      tableId,
      productId: it.productId ?? null,
      name,
      label: it.label ?? '',
      brand: it.brand ?? '',
      category: it.category ?? '',
      section: it.section ?? null,
      subCategory: it.subCategory ?? '',
      price,
      quantity,
      printTarget,
      printGroup,
      printed: { kitchen: false, register: false, receipt: false },
      orderedBy: it.orderedBy ?? 'owner',
      shouldPrint: it.shouldPrint !== false,
      createdAt: new Date().toISOString(),
    };

    store.orderItems.set(itemId, normalized);
    itemIds.push(itemId);
  });

  if (itemIds.length === 0) {
    store.ordersByTable.set(tableId, []);
    return { orderId: null, itemCount: 0 };
  }

  store.orderItemsByOrder.set(orderId, itemIds);
  return { orderId, itemCount: itemIds.length };
}

// --------------------
// オーダー表 手動印刷
// --------------------
app.post("/api/print/order", async (req, res) => {
 

  if (!tableId || !target) {
    return res.json({ success: false, message: "tableId and target are required" });
  }

  try {
    const result = await printOrderSlip({ tableId, target });
    return res.json({ success: true, ...result });
  } catch (e) {
    console.error("PRINT ORDER ERROR:", e);
    return res.json({ success: false, message: "print failed" });
  }
});

// --------------------
// 会計伝票 印刷
// --------------------
app.post("/api/print/receipt", async (req, res) => {
  console.log("PRINT RECEIPT API CALLED", req.body);

  const { tableId } = req.body;
  if (!tableId) {
    return res.json({ success: false, message: "tableId is required" });
  }

  try {
    const summary = calcReceiptSummary(tableId);

    const segments = buildReceiptText({
      tableId,
      items: summary.items.map((i) => ({
        name: printableReceiptItemName(i),
        qty: i.quantity,
        priceEx: i.price,
      })),
      summary: {
        taxableSubtotal: summary.taxableSubtotal,
        tax: summary.tax,
        service: summary.service,
        total: summary.total,
      },
    });
 
    await enqueuePrint(segments, "receipt");

    return res.json({ success: true });
  } catch (e) {
    console.error("PRINT RECEIPT ERROR:", e);
    return res.json({ success: false, message: "print failed" });
  }
});

// =========================
// キャストドリンク（GET/POST）
// =========================
const CAST_DRINKS_FILE = resolveDataPath("cast_drinks.json");
app.get("/api/cast-drinks", (req, res) => {
  try {
    if (!fs.existsSync(CAST_DRINKS_FILE)) return res.json([]);

    const json = JSON.parse(fs.readFileSync(CAST_DRINKS_FILE, "utf8") || "{}");
    res.json(json.items || []);
  } catch (_) {
    res.json([]);
  }
});

app.post("/api/cast-drinks", (req, res) => {
  const items = req.body.items;
  if (!Array.isArray(items)) {
    return res.status(400).json({ error: "items is required" });
  }

  fs.writeFileSync(
    CAST_DRINKS_FILE,
    JSON.stringify({ updatedAt: new Date(), items }, null, 2),
    "utf8"
  );

  res.json({ success: true });
});

// =========================
// キャスト（GET/POST）
// =========================
const CASTS_FILE = resolveDataPath("casts.json");

app.get("/api/casts", (req, res) => {
  try {
    if (!fs.existsSync(CASTS_FILE)) return res.json({ casts: [] });

    const raw = fs.readFileSync(CASTS_FILE, "utf-8");
    if (!raw) return res.json({ casts: [] });

    const json = JSON.parse(raw);
    const casts = Array.isArray(json.casts) ? json.casts : [];
    res.json({ casts });
  } catch (_) {
    res.json({ casts: [] });
  }
});

app.post("/api/casts", (req, res) => {
  try {
    const casts = Array.isArray(req.body.casts) ? req.body.casts : [];
    fs.writeFileSync(CASTS_FILE, JSON.stringify({ casts }, null, 2), "utf-8");
    res.json({ ok: true });
  } catch (_) {
    res.status(500).json({ ok: false });
  }
});

// =========================
// セット（GET/POST）
// =========================
const SETS_FILE = resolveDataPath("sets.json");

app.get("/api/sets", (req, res) => {
  try {
    if (!fs.existsSync(SETS_FILE)) return res.json({ sets: [] });

    const raw = fs.readFileSync(SETS_FILE, "utf-8");
    if (!raw) return res.json({ sets: [] });

    const json = JSON.parse(raw);
    const sets = Array.isArray(json.sets) ? json.sets : [];
    res.json({ sets });
  } catch (_) {
    res.json({ sets: [] });
  }
});

app.post("/api/sets", (req, res) => {
  try {
    const sets = Array.isArray(req.body.sets) ? req.body.sets : [];
    fs.writeFileSync(SETS_FILE, JSON.stringify({ sets }, null, 2), "utf-8");
    res.json({ ok: true });
  } catch (_) {
    res.status(500).json({ ok: false });
  }
});

// =========================
// その他（GET/POST）
// =========================
const OTHER_ITEMS_FILE = resolveDataPath("other_items.json");
app.get("/api/other-items", (req, res) => {
  try {
    if (!fs.existsSync(OTHER_ITEMS_FILE)) return res.json({ items: [] });

    const raw = fs.readFileSync(OTHER_ITEMS_FILE, "utf8");
        const json = JSON.parse(raw || "{}");
    res.json({ items: json.items || [] });
  } catch (e) {
    console.error("other-items GET error", e);
    res.json({ items: [] });
  }
});

app.post("/api/other-items", (req, res) => {
  try {
    const items = req.body.items;
    if (!Array.isArray(items)) {
      return res.status(400).json({ error: "items must be array" });
    }

    fs.writeFileSync(
      OTHER_ITEMS_FILE,
      JSON.stringify({ items }, null, 2),
      "utf8"
    );

    res.json({ ok: true });
  } catch (e) {
    console.error("other-items POST error", e);
    res.status(500).json({ error: "save failed" });
  }
});

// =========================
// 宣材（GET/POST）
// =========================
const PROMOS_FILE = resolveDataPath("promos.json");

app.get("/api/promos", (req, res) => {
  try {
    if (!fs.existsSync(PROMOS_FILE)) {
      return res.json({ top: [], bottom: [] });
    }

    const raw = fs.readFileSync(PROMOS_FILE, "utf8");
    const json = JSON.parse(raw || "{}");

    res.json({
      top: Array.isArray(json.top) ? json.top : [],
      bottom: Array.isArray(json.bottom) ? json.bottom : [],
    });
  } catch (e) {
    console.error("promos GET error", e);
    res.json({ top: [], bottom: [] });
  }
});

app.post("/api/promos", (req, res) => {
  try {
    const { top, bottom } = req.body;

    if (!Array.isArray(top) || !Array.isArray(bottom)) {
      return res.status(400).json({ error: "top and bottom must be arrays" });
    }

    fs.writeFileSync(
      PROMOS_FILE,
      JSON.stringify({ top, bottom }, null, 2),
      "utf8"
    );

    res.json({ ok: true });
  } catch (e) {
    console.error("promos POST error", e);
    res.status(500).json({ error: "save failed" });
  }
});

// =========================
// listen（必ず最後）
// =========================


app.post("/api/promos/delete-file", (req, res) => {
  const { url } = req.body;
  if (!url) {
    return res.status(400).json({ error: "url required" });
  }

  // /uploads/promos/xxx.jpg → 実ファイルパス
  const filePath = path.join(__dirname, url);

  // uploads 配下以外は削除させない（安全）
  if (!filePath.startsWith(path.join(__dirname, "uploads"))) {
    return res.status(400).json({ error: "invalid path" });
  }

  if (fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
  }

  res.json({ ok: true });
});

// =========================
// 注文確定（最小・ダミー）
// =========================
 app.post("/api/orders",  async(req, res) => {
  console.log("ORDER RECEIVED", req.body);

  const requestId = String(req.body.requestId ?? "").trim();
  if (requestId) {
    const remembered = getRememberedOrderRequest(requestId);
    if (remembered) {
      return res.json(remembered);
    }
  }

 // Flutter 側の payload が items/lines/order のどれでも動くように吸収
  const tableId = String(req.body.tableId ?? req.body.table ?? "").trim();
  const rawItems =
    (Array.isArray(req.body.items) && req.body.items) ||
    (Array.isArray(req.body.lines) && req.body.lines) ||
    (req.body.order && Array.isArray(req.body.order.lines) && req.body.order.lines) ||
    [];

  const validationErrors = [];

  if (!tableId) {
    validationErrors.push("tableId is required");
  }

  if (rawItems.length === 0) {
    validationErrors.push("items must be a non-empty array");
  }

  const invalidItems = rawItems
    .map((it, idx) => {
      if (!it || typeof it !== "object") {
        return `items[${idx}] must be object`;
      }

      const qty = Number(it.qty ?? it.quantity ?? 1);
      if (!Number.isFinite(qty) || qty <= 0) {
        return `items[${idx}].qty must be > 0`;
      }

      const price = Number(it.price ?? 0);
      if (!Number.isFinite(price) || price < 0) {
        return `items[${idx}].price must be >= 0`;
      }
 const productId = it.productId;
      if (productId != null && productId !== "" && !store.products.has(productId)) {
        return `items[${idx}].productId is invalid: ${productId}`;
      }
      return null;
    })
    .filter(Boolean);

  if (invalidItems.length > 0) {
    validationErrors.push(...invalidItems);
  }

  if (validationErrors.length > 0) {
     console.warn("ORDER VALIDATION FAILED", {
      requestId,
      tableId,
      details: validationErrors,
      bodyKeys: Object.keys(req.body || {}),
    });
    return res.status(400).json({
      ok: false,
      success: false,
      error: "invalid payload (tableId/items)",
      details: validationErrors,
    });
  }

 // ★ 注文確定時：テーブルは必ず「開始中」にする（正本）
store.openTable(tableId);



  // ② orderId を作る
  const orderId = "order_" + Date.now();

  // ③ テーブル → orderId を紐づけ
  if (!store.ordersByTable.has(tableId)) {
    store.ordersByTable.set(tableId, []);
  }
  store.ordersByTable.get(tableId).push(orderId);

  // ④ orderId → itemIds を作る（getTableItems がここを見る）
  if (!store.orderItemsByOrder) store.orderItemsByOrder = new Map();
  const itemIds = [];

  // ⑤ item を 1件ずつ store.orderItems に保存（key は itemId）
  //    ※ printOrderSlip が見る shape に寄せる
 
try {
    rawItems.forEach((it, idx) => {
      const itemId = `item_${Date.now()}_${idx}`;

      const quantity = Number(it.qty ?? it.quantity ?? 1);
      const price = Number(it.price ?? 0);

      const name =
        it.name ??
        (it.brand && it.label ? `${it.brand} / ${it.label}` : (it.label ?? "unknown"));

      // ① 何を刷るか（drink / food）
      const printTarget = it.printTarget ?? "drink";

      // ② どのプリンタへ（kitchen / register）
      const printGroup = normalizePrintTarget(it.printGroup ?? printTarget);
      const orderedBy = req.body.orderedBy ?? "guest";

      // 表示系（RT snapshot）とサーバー正本（orderItems）で同じ lineId を持つ
      const tableLine = it.productId
        ? store.addTableItem(tableId, {
            productId: it.productId,
            qty: quantity,
            addedBy: orderedBy,
          })
        : store.addTableItemSnapshot(tableId, {
            name,
            label: it.label ?? "",
            brand: it.brand ?? "",
            category: it.category ?? "",
            section: it.section ?? null,
            subCategory: it.subCategory ?? "",
            printGroup,
            price,
            qty: quantity,
            addedBy: orderedBy,
          });

      const normalized = {
        id: itemId,
        orderId,
        tableId,
        productId: it.productId ?? null,
        name,
        label: it.label ?? "",
        brand: it.brand ?? "",
        category: it.category ?? "",
        section: it.section ?? null,
        subCategory: it.subCategory ?? "",
        price,
        quantity,
        printTarget,
        printGroup,
        printed: { kitchen: false, register: false, receipt: false },
        orderedBy,
        shouldPrint: it.shouldPrint !== false,
        createdAt: new Date().toISOString(),
        rtLineId: tableLine?.lineId ?? null,
      };

      store.orderItems.set(itemId, normalized);
      itemIds.push(itemId);
    });
  } catch (e) {
    console.error("ORDER PROCESSING ERROR", {
      message: e?.message,
      tableId,
      requestId,
    });
    return res.status(400).json({
      ok: false,
      success: false,
      error: "order processing failed",
      details: [e?.message || "unknown error"],
    });
  }

   store.orderItemsByOrder.set(orderId, itemIds);

  // ⑥ 通常注文も RT注文と同様に自動印刷
  const createdItems = itemIds
    .map((id) => store.orderItems.get(id))
    .filter((item) => item && item.shouldPrint !== false);

  const printTargets = Array.from(
    new Set(
      createdItems.map((item) =>
        normalizePrintTarget(item.printGroup ?? item.printTarget)
      )
    )
  ).filter((t) => t !== "none");

  for (const target of printTargets) {
    try {
      await printOrderSlip({
        tableId,
        target,
        items: createdItems,
      });
    } catch (e) {
      console.error("ORDER AUTO PRINT ERROR:", e);
    }
  }

  // ⑦ 全端末に snapshot 配信
  broadcastSnapshot();

  const responsePayload = {
    ok: true,
    success: true,
    orderId,
    itemCount: itemIds.length,
  };
  if (requestId) {
    rememberOrderRequest(requestId, responsePayload);
  }

  res.json(responsePayload);


});



app.post('/api/orders/sync-table', (req, res) => {
  const tableId = String(req.body.tableId ?? '').trim();
  const lines = Array.isArray(req.body.lines) ? req.body.lines : [];

  if (!tableId) {
    return res.status(400).json({ success: false, error: 'tableId is required' });
  }

  replaceTableItems(tableId, lines);
  broadcastSnapshot();
  return res.json({ success: true });
});

// =========================
// =========================
// snapshot 作成（RT 正本）
// =========================
function buildSnapshot() {
  return {
    type: "snapshot",
    payload: store.buildRealtimeSnapshot(), // ★ ここが正本
  };
}


  // ★ ここを追加 ★

///////////////////
function broadcastSnapshot() {
  const data = JSON.stringify(buildSnapshot()); // ★ここだけ
  for (const client of wss.clients) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(data);
    }
  }
}

// =========================
// listen（必ず最後）
// =========================
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });
wss.on("connection", (ws) => {
  console.log("WebSocket connected. clients =", wss.clients.size);

  // 接続時に snapshot を1回送る（既存の buildSnapshot を使う）
  ws.send(JSON.stringify(buildSnapshot()));


  ws.on("close", () => {
    console.log("WebSocket disconnected. clients =", wss.clients.size);
  });
});


server.listen(3000, () => {
  console.log("server started :3000");
});
// =========================
// RT 注文：追加（tableOrders 用）
// =========================
app.post("/api/rt/tables/:tableId/items", async (req, res) => {
  try {
    const { tableId } = req.params;
    const { productId, qty, addedBy, shouldPrint } = req.body;
     // ★ 追加：開始チェック
    const table = store.getTable(tableId);
    if (!table || table.status !== "ordering") {
      return res.status(400).json({ ok: false, error: "table not active" });
    }

     const line = store.addTableItem(tableId, {
      productId,
      qty,
      addedBy, // "guest" or "owner"
    });

    // RT注文も印刷/会計系の orderItems 正本へ同期する
    const product = store.getProduct(line.productId);
    const orderId = `rt_order_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
    const itemId = `rt_item_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
    const printTarget = product?.printTarget ?? "kitchen";
    const normalizedPrintTarget = normalizePrintTarget(printTarget);

    if (!store.ordersByTable.has(tableId)) {
      store.ordersByTable.set(tableId, []);
    }
    store.ordersByTable.get(tableId).push(orderId);

    store.orderItems.set(itemId, {
      id: itemId,
      orderId,
      tableId,
      productId: line.productId,
      name: line.name,
      label: product?.variantLabel ?? "",
      brand: product?.name ?? line.name,
      category: product?.category ?? "",
      section: null,
      subCategory: "",
      price: Number(line.price ?? 0),
     quantity: Number(line.qty ?? 1),
      printTarget,
      printGroup: normalizedPrintTarget,
      printed: { kitchen: false, register: false, receipt: false },
      orderedBy: line.addedBy ?? "guest",
      shouldPrint: shouldPrint !== false,
      createdAt: new Date().toISOString(),
      rtLineId: line.lineId,
    });

    store.orderItemsByOrder.set(orderId, [itemId]);

    // ★ 追加後に全端末へ snapshot 配信
    broadcastSnapshot();

    // RT注文確定時も注文票を自動印刷
    if (shouldPrint !== false) {
      try {
        await printOrderSlip({
          tableId,
          target: normalizedPrintTarget,
          items: [store.orderItems.get(itemId)],
        });
      } catch (e) {
        console.error("RT AUTO PRINT ORDER ERROR:", e);
      }
    }

    res.json({ ok: true, line });
  } catch (e) {
    console.error("RT ADD ERROR:", e);
    res.status(400).json({ ok: false, error: e.message });
  }
});
// =========================
// RT 注文：数量変更（tableOrders 用）
// =========================
app.patch("/api/rt/tables/:tableId/items/:lineId", (req, res) => {
  try {
    const { tableId, lineId } = req.params;
    const { qty } = req.body;

   const line = store.updateTableItemQty(tableId, lineId, qty);

    // RT行に紐づく印刷/会計用アイテム数量も同期
    for (const item of store.orderItems.values()) {
      if (item.tableId === tableId && item.rtLineId === String(lineId)) {
        item.quantity = Number(qty);
      }
    }

    // ★ 変更後に全端末へ snapshot 配信
    broadcastSnapshot();

    res.json({ ok: true, line });
  } catch (e) {
    console.error("RT QTY UPDATE ERROR:", e);
    res.status(400).json({ ok: false, error: e.message });
  }
});
// =========================
// RT 注文：削除（tableOrders 用）
// =========================
app.delete("/api/rt/tables/:tableId/items/:lineId", (req, res) => {
  try {
    const { tableId, lineId } = req.params;

    store.removeTableItem(tableId, lineId);

    // RT行に紐づく印刷/会計用アイテムも削除
    const removedItemIds = [];
    for (const [itemId, item] of store.orderItems.entries()) {
      if (item.tableId === tableId && item.rtLineId === String(lineId)) {
        removedItemIds.push(itemId);
      }
    }

    for (const itemId of removedItemIds) {
      const item = store.orderItems.get(itemId);
      if (!item) continue;

      const itemIds = store.orderItemsByOrder.get(item.orderId) || [];
      const next = itemIds.filter((id) => id !== itemId);

      if (next.length === 0) {
        store.orderItemsByOrder.delete(item.orderId);
        const orderIds = store.ordersByTable.get(tableId) || [];
        store.ordersByTable.set(
          tableId,
          orderIds.filter((id) => id !== item.orderId)
        );
      } else {
        store.orderItemsByOrder.set(item.orderId, next);
      }

      store.orderItems.delete(itemId);
    }

    // ★ 削除後に全端末へ snapshot 配信
    broadcastSnapshot();

    res.json({ ok: true });
  } catch (e) {
    console.error("RT DELETE ERROR:", e);
    res.status(400).json({ ok: false, error: e.message });
  }
});

// =========================
// RT：席移動
// =========================
app.post("/api/rt/tables/move", (req, res) => {
  try {
    const { from, to } = req.body;
    if (!from || !to) {
      return res.status(400).json({ ok: false, error: "from/to required" });
    }

    store.moveTableOrderSnapshot(from, to);
    broadcastSnapshot();

    res.json({ ok: true });
  } catch (e) {
    console.error("RT TABLE MOVE ERROR:", e);
    res.status(400).json({ ok: false, error: e.message });
  }
});

// =========================
// RT：席合算
// =========================
app.post("/api/rt/tables/merge", (req, res) => {
  try {
    const { from, to } = req.body;
    if (!from || !to) {
      return res.status(400).json({ ok: false, error: "from/to required" });
    }

    store.mergeTableOrderSnapshot(from, to);
    broadcastSnapshot();

    res.json({ ok: true });
  } catch (e) {
    console.error("RT TABLE MERGE ERROR:", e);
    res.status(400).json({ ok: false, error: e.message });
  }
});
// =========================
// テーブル開始
// =========================
app.post("/api/rt/tables/:tableId/start", (req, res) => {
  const { tableId } = req.params;

  try {
    store.openTable(tableId);   // ★ 正本はサーバー
    broadcastSnapshot();        // ★ 全端末に通知
    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message });
  }
});

// =========================
// テーブル終了
// =========================
app.post("/api/rt/tables/:tableId/end", (req, res) => {
  const { tableId } = req.params;

  try {
    store.closeTable(tableId);
    broadcastSnapshot();
    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ ok: false, error: e.message });
  }
});

app.get("/api/printer-settings", (req, res) => {
  res.json(readPrinterSettings());
});

app.post("/api/printer-settings", (req, res) => {
  const input = req.body || {};

  const normalized = {
    kitchen: {
      host: String(input?.kitchen?.host ?? "").trim(),
      port: Number(input?.kitchen?.port) || 9100,
    },
    register: {
      host: String(input?.register?.host ?? "").trim(),
      port: Number(input?.register?.port) || 9100,
    },
    receipt: {
      host: String(input?.receipt?.host ?? "").trim(),
      port: Number(input?.receipt?.port) || 9100,
    },
  };

  savePrinterSettings(normalized);
  applyPrinterSettingsToEnv(normalized);

  res.json({ success: true, settings: normalized });
});