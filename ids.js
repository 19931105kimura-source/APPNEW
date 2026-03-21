// src/ids.js
let seq = {
  order: 0,
  orderItem: 0,
};

function nextOrderId() {
  seq.order += 1;
  return `o_${seq.order}`;
}

function nextOrderItemId() {
  seq.orderItem += 1;
  return `oi_${seq.orderItem}`;
}

module.exports = {
  nextOrderId,
  nextOrderItemId,
};
