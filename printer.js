// src/printer.js
const { exec } = require("child_process");
const fs = require("fs");
const net = require("net");
const path = require("path");
const iconv = require("iconv-lite");

// ===== 変更後 =====
const PRINTER_MAP = {
  drink:    "Star mC-Print3",
  food:     "Star mC-Print3",
  register: "Star mC-Print3",
  kitchen:  "Star mC-Print3",
  receipt:  "Star mC-Print3",
};

function normalizePrintableText(text) {
  return String(text ?? "")
    .replace(/[─━]/g, "-")
    .replace(/[（]/g, "(")
    .replace(/[）]/g, ")")
    .replace(/\u3000/g, "  ");
}

function toCP932(text) {
  return iconv.encode(normalizePrintableText(text), "cp932");
}

// ===== 変更後 =====
const CMD = {
  init: Buffer.from([0x1b, 0x40]),
  emphasisOn:  Buffer.from([0x1b, 0x45, 0x01]), // ESC E n=1（太字ON）
  emphasisOff: Buffer.from([0x1b, 0x45, 0x00]), // ESC E n=0（太字OFF）
  feed: Buffer.from([0x1b, 0x64, 0x03]),
  cut: Buffer.from([0x1d, 0x56, 0x01]),          // GS V m=1（パーシャルカット）
};

function cp932PadEnd(text, targetBytes) {

  let s = normalizePrintableText(text);
  let buf = toCP932(s);

  while (buf.length < targetBytes) {
    s += " ";
    buf = toCP932(s);
  }

  if (buf.length > targetBytes) {

    let trimmed = "";

    for (const ch of s) {

      const next = trimmed + ch;

      if (toCP932(next).length > targetBytes) break;

      trimmed = next;
    }

    s = trimmed;
    buf = toCP932(s);

    while (buf.length < targetBytes) {
      s += " ";
      buf = toCP932(s);
    }
  }

  return buf;
}

function buildLine(leftBuf, rightBuf, totalBytes) {

  const padBytes = totalBytes - leftBuf.length - rightBuf.length;

  const pad = Buffer.alloc(Math.max(0, padBytes), 0x20);

  return Buffer.concat([
    leftBuf,
    pad,
    rightBuf,
    Buffer.from([0x0a]),
  ]);
}

function formatAmountBuf(yenStr) {
  const num = yenStr.startsWith("¥") ? yenStr.slice(1) : yenStr;
  const padded = num.padStart(9);
  return Buffer.concat([
    Buffer.from([0x5c]),
    Buffer.from(padded, "ascii"),
  ]);
}
function fixedRightBuf(yenStr) {
  const RIGHT_WIDTH = 11;
  const num = yenStr.startsWith("¥") ? yenStr.slice(1) : yenStr;
  const numBuf = Buffer.from(num, "ascii");
  const yenByte = Buffer.from([0x5c]);
  const padBytes = RIGHT_WIDTH - numBuf.length - 1;
  const pad = Buffer.alloc(Math.max(0, padBytes), 0x20);
  return Buffer.concat([pad, yenByte, numBuf]);
}
function centerLine(text, totalBytes) {

  const buf = toCP932(text);

  const pad = Math.max(0, Math.floor((totalBytes - buf.length) / 2));

  return Buffer.concat([
    Buffer.alloc(pad, 0x20),
    buf,
    Buffer.from([0x0a]),
  ]);
}

function buildRawPrintData(segments) {

  const chunks = [];

  chunks.push(CMD.init);

  const ROW_BYTES = 42; // 72mm printable
  const MARGIN = 1;
  const AMOUNT_BYTES = 8;
  const QTY_BYTES = 3;
  const SEP = 1;

  for (const seg of segments) {
   if (seg.type === "title") {

      chunks.push(centerLine(seg.text, ROW_BYTES));
    }
   else if (seg.type === "item") {

      const nameWidth = Number(seg.nameWidth || 0);
      const qtyWidth = Number(seg.qtyWidth || QTY_BYTES);

      const nameBuf = cp932PadEnd(seg.name, nameWidth);

      const qtyBuf = Buffer.from(
        String(seg.qty).padStart(qtyWidth),
        "ascii"
      );

      const leftBuf = Buffer.concat([nameBuf, qtyBuf]);

       const rightBuf = fixedRightBuf(seg.price);

      chunks.push(buildLine(leftBuf, rightBuf, ROW_BYTES));

      for (const extra of seg.nameExtra || []) {
        chunks.push(
          Buffer.concat([
            toCP932(extra),
            Buffer.from([0x0a]),
          ])
        );
      }
    }

    else if (seg.type === "labelright") {

      const labelBuf = toCP932(seg.label);

     const rightBuf = fixedRightBuf(seg.amount);

      chunks.push(buildLine(labelBuf, rightBuf, ROW_BYTES));
    }

    else if (seg.type === "total") {

      chunks.push(CMD.emphasisOn);

      const labelBuf = toCP932("合計");

     const rightBuf = fixedRightBuf(seg.amount);

      chunks.push(buildLine(labelBuf, rightBuf, ROW_BYTES));

      chunks.push(CMD.emphasisOff);
    }

    else if (seg.type === "footer") {

      chunks.push(centerLine(seg.text, ROW_BYTES));
    }

    else {

      chunks.push(Buffer.concat([toCP932(seg.text)]));
    }
  }

  chunks.push(Buffer.from([0x0a, 0x0a, 0x0a]));

  chunks.push(CMD.feed);

  chunks.push(CMD.cut);

  return Buffer.concat(chunks);
}

function resolveRawTcpConfig(target) {

  const key = String(target || "receipt").toUpperCase();

  const host =
    process.env[`PRINTER_${key}_HOST`] ||
    process.env.PRINTER_HOST;

  const portRaw =
    process.env[`PRINTER_${key}_PORT`] ||
    process.env.PRINTER_PORT;

  const port = Number(portRaw || 9100);

  if (!host) return null;

  return { host, port };
}

function printTextRawTcp(segments, { host, port }) {

  return new Promise((resolve, reject) => {

    const socket = net.createConnection(port, host);

    socket.on("connect", () => {

      try {

        const data = buildRawPrintData(segments);

        socket.write(data, () => {

          setTimeout(() => {

            socket.end();

            resolve();

          }, 200);
        });

      } catch (err) {

        reject(err);
      }
    });

    socket.on("error", reject);
  });
}

function printTextWindows(segments, target = "receipt") {

  return new Promise((resolve, reject) => {

    const transport =
      (process.env.PRINT_TRANSPORT || "rawtcp").toLowerCase();

    if (transport === "rawtcp") {

      const tcpConfig = resolveRawTcpConfig(target);

      if (!tcpConfig) {

        return reject(
          new Error("Printer host not set")
        );
      }

      printTextRawTcp(segments, tcpConfig)
        .then(resolve)
        .catch(reject);

      return;
    }

    const printerName = PRINTER_MAP[target];

    const text =
      segments.map(s => s.text || "").join("\n");

    const filePath =
      path.join(__dirname, `print_${Date.now()}.txt`);

    fs.writeFileSync(filePath, text, "utf8");

    const cmd =
      `powershell -NoProfile -Command "Get-Content '${filePath}' | Out-Printer -Name '${printerName}'"`;

    exec(cmd, (err) => {

      if (err) return reject(err);

      resolve();
    });
  });
}

const printerQueues = {
  kitchen: [],
  register: [],
  receipt: [],
};

const printerQueueProcessing = {
  kitchen: false,
  register: false,
  receipt: false,
};

function normalizeQueueTarget(target) {
  const key = String(target || "receipt").toLowerCase();
  if (key === "food") return "register";
  if (key === "drink") return "kitchen";
  if (key === "kitchen" || key === "register" || key === "receipt") {
    return key;
  }
  return "receipt";
}

function enqueuePrint(segments, target = "receipt") {
  const queueTarget = normalizeQueueTarget(target);

  return new Promise((resolve, reject) => {
    printerQueues[queueTarget].push({
      segments,
      target: queueTarget,
      resolve,
      reject,
    });
    void processPrintQueue(queueTarget);
  });
}

async function processPrintQueue(target) {
  if (printerQueueProcessing[target]) return;

  printerQueueProcessing[target] = true;

  try {
    while (printerQueues[target].length > 0) {
      const job = printerQueues[target].shift();
      if (!job) continue;

      try {
        await printTextWindows(job.segments, job.target);
        job.resolve();
      } catch (error) {
        job.reject(error);
      }
    }
  } finally {
    printerQueueProcessing[target] = false;
  }
}

module.exports = {
  enqueuePrint,
  normalizeQueueTarget,
  processPrintQueue,
  printerQueues,
  printerQueueProcessing,
  printTextWindows,
  printTextRawTcp,
  resolveRawTcpConfig,
  PRINTER_MAP,
  buildRawPrintData,
  };