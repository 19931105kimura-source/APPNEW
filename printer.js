// src/printer.js
const { exec } = require("child_process");
const fs = require("fs");
const net = require("net");
const path = require("path");
const iconv = require("iconv-lite");

const PRINTER_MAP = {
  drink:    "Star mC-Print3",
  food:     "Star mC-Print3",
  register: "Star mC-Print3",
  kitchen:  "Star mC-Print3",
  receipt:  "Star mC-Print3",
};

function toFullWidth(str) {
  // 半角英数字・記号 → 全角に変換
  return String(str ?? "").replace(/[!-~]/g, (c) =>
    String.fromCharCode(c.charCodeAt(0) + 0xfee0)
  );
}

function normalizePrintableText(text) {
  return toFullWidth(String(text ?? "")
    .replace(/[─━]/g, "-")
    .replace(/[（]/g, "(")
    .replace(/[）]/g, ")")
    .replace(/\u3000/g, "  "));
}

function toCP932(text) {
  return iconv.encode(normalizePrintableText(text), "cp932");
}

const CMD = {
  init:          Buffer.from([0x1b, 0x40]),
  emphasisOn:    Buffer.from([0x1b, 0x45, 0x01]),  // ESC E 1（太字ON）
  emphasisOff:   Buffer.from([0x1b, 0x45, 0x00]),  // ESC E 0（太字OFF）
  // StarPRNT: 横2倍・縦2倍
  textWidthOn:   Buffer.from([0x1b, 0x57, 0x01]),  // ESC W 1（横2倍ON）
  textWidthOff:  Buffer.from([0x1b, 0x57, 0x00]),  // ESC W 0（横2倍OFF）
  textHeightOn:  Buffer.from([0x1b, 0x68, 0x01]),  // ESC h 1（縦2倍ON）
  textHeightOff: Buffer.from([0x1b, 0x68, 0x00]),  // ESC h 0（縦2倍OFF）
  // StarPRNT: External Buzzer 1（短く1回）
  buzzerSetupShortOnce: Buffer.from([0x1b, 0x1d, 0x19, 0x11, 0x01, 0x01, 0x01]),
  buzzerRunOnce:        Buffer.from([0x1b, 0x1d, 0x19, 0x12, 0x01, 0x01, 0x00]),
  feed: Buffer.from([0x1b, 0x64, 0x03]),
  cut:  Buffer.from([0x1d, 0x56, 0x01]),            // GS V m=1（パーシャルカット）
};


function cp932PadEnd(text, targetBytes) {

  let s = normalizePrintableText(text);
  let buf = toCP932(s);

  if (buf.length > targetBytes) {

    let trimmed = "";

    for (const ch of s) {

      const next = trimmed + ch;

      if (toCP932(next).length > targetBytes) break;

      trimmed = next;
    }

    s = trimmed;
    buf = toCP932(s);
  }

  // 全角スペース（CP932: 0x8140）で埋めて、余り1バイトは半角スペースで補う
  const wideSpaceBuf = Buffer.from([0x81, 0x40]);
  while (targetBytes - buf.length >= 2) {
    buf = Buffer.concat([buf, wideSpaceBuf]);
  }
  while (buf.length < targetBytes) {
    buf = Buffer.concat([buf, Buffer.from([0x20])]);
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

function fixedRightBuf(yenStr, offset = 0) {
  const RIGHT_WIDTH = 11;
  const num = yenStr.startsWith("¥") ? yenStr.slice(1) : yenStr;
  const numBuf = Buffer.from(num, "ascii");
  const yenByte = Buffer.from([0x5c]);
  const padBytes = RIGHT_WIDTH - numBuf.length - 1 - offset;
  const pad = Buffer.alloc(Math.max(0, padBytes), 0x20);
  return Buffer.concat([pad, yenByte, numBuf]);
}

function fixedRightBufWithOffset(yenStr, offset) {
  const RIGHT_WIDTH = 11;
  const num = yenStr.startsWith("¥") ? yenStr.slice(1) : yenStr;
  const numBuf = Buffer.from(num, "ascii");
  const yenByte = Buffer.from([0x5c]);
  const padBytes = RIGHT_WIDTH - numBuf.length - 1 - offset;
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

// 全角文字数をカウントする（CP932で2バイトになる文字）
function countWideChars(text) {
  let count = 0;
  for (const c of String(text ?? "")) {
    const code = c.charCodeAt(0);
    if (code === 0x00D7) { count++; continue; }
    if (
      (code >= 0x3000 && code <= 0x9fff) ||
      (code >= 0xff00 && code <= 0xffef)
    ) count++;
  }
  return count;
}

function buildRawPrintData(segments, target = "receipt") {

  const chunks = [];

  chunks.push(CMD.init);

  const PAPER_BYTES = 48;          // 用紙の印字可能幅
  const ROW_BYTES   = 42; // マージンなしで用紙全幅を使用

  const QTY_BYTES = 3;

  for (const seg of segments) {

    if (seg.type === "title") {

      chunks.push(centerLine(seg.text, ROW_BYTES));
    }

    else if (seg.type === "item") {

      const nameWidth = Number(seg.nameWidth || 0);
      const qtyWidth  = Number(seg.qtyWidth  || QTY_BYTES);

      const nameBuf  = cp932PadEnd(seg.name, nameWidth);
      const qtyBuf   = Buffer.from(String(seg.qty).padStart(qtyWidth), "ascii");
      const leftBuf  = Buffer.concat([nameBuf, qtyBuf]);
      const rightBuf = fixedRightBuf(seg.price);

      chunks.push(buildLine(leftBuf, rightBuf, ROW_BYTES));

      for (const extra of seg.nameExtra || []) {
        chunks.push(
          Buffer.concat([
            cp932PadEnd(extra, Number(seg.nameWidth || 0)),
            Buffer.from([0x0a]),
          ])
        );
      }
    }

  else if (seg.type === "labelright") {

  const LEFT_WIDTH = ROW_BYTES - 11; // 42 - priceWidth(11) = 31
  const labelBuf = cp932PadEnd(seg.label, LEFT_WIDTH);
  const rightBuf = fixedRightBuf(seg.amount);

  chunks.push(buildLine(labelBuf, rightBuf, ROW_BYTES));
}

    else if (seg.type === "total") {

  chunks.push(CMD.emphasisOn);
  chunks.push(CMD.textWidthOn);
  chunks.push(CMD.textHeightOn);

  const num = seg.amount.startsWith("¥") ? seg.amount.slice(1) : seg.amount;
  const text = "合計  ¥" + num;

  chunks.push(Buffer.concat([
    toCP932(text),
    Buffer.from([0x0a])
  ]));

  chunks.push(CMD.textHeightOff);
  chunks.push(CMD.textWidthOff);
  chunks.push(CMD.emphasisOff);
}

    else if (seg.type === "footer") {

      chunks.push(centerLine(seg.text, ROW_BYTES));
    }

    else {

      // 罫線（-や=のみの行）は全角変換せず直接ASCIIで送る
      const textStr = String(seg.text ?? "");
      const isRule  = /^[-=\n]+$/.test(textStr);
      if (isRule) {
        chunks.push(Buffer.from(textStr, "ascii"));
      } else {
        chunks.push(toCP932(textStr));
      }
    }
  }

  chunks.push(Buffer.from([0x0a, 0x0a, 0x0a]));
  chunks.push(CMD.feed);

  if (String(target).toLowerCase() === "kitchen") {
    chunks.push(CMD.buzzerSetupShortOnce);
    chunks.push(CMD.buzzerRunOnce);
  }

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

function printTextRawTcp(segments, target, { host, port }) {

  return new Promise((resolve, reject) => {

    const socket = net.createConnection(port, host);

    socket.on("connect", () => {

      try {

        const data = buildRawPrintData(segments, target);

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

    const transport = (process.env.PRINT_TRANSPORT || "rawtcp").toLowerCase();

    if (transport === "rawtcp") {

      const tcpConfig = resolveRawTcpConfig(target);

      if (!tcpConfig) {
        return reject(new Error("Printer host not set"));
      }

      printTextRawTcp(segments, target, tcpConfig)
        .then(resolve)
        .catch(reject);

      return;
    }

    const printerName = PRINTER_MAP[target];
    const text = segments.map(s => s.text || "").join("\n");
    const filePath = path.join(__dirname, `print_${Date.now()}.txt`);

    fs.writeFileSync(filePath, text, "utf8");

    const cmd = `powershell -NoProfile -Command "Get-Content '${filePath}' | Out-Printer -Name '${printerName}'"`;

    exec(cmd, (err) => {
      if (err) return reject(err);
      resolve();
    });
  });
}

const printerQueues = {
  kitchen:  [],
  register: [],
  receipt:  [],
};

const printerQueueProcessing = {
  kitchen:  false,
  register: false,
  receipt:  false,
};

function normalizeQueueTarget(target) {
  const key = String(target || "receipt").toLowerCase();
  if (key === "food")  return "register";
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