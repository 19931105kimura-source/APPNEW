const net = require("net");

const client = new net.Socket();

client.connect(9100,"192.168.11.200",() => {

  let data = [];

  data.push(Buffer.from([0x1B,0x40])); // init
  data.push(Buffer.from("ESC POS TEST\n"));
  data.push(Buffer.from([0x1B,0x61,0x01]));
  data.push(Buffer.from("CENTER\n"));

  data.push(Buffer.from([0x1D,0x56,0x00])); // cut

  client.write(Buffer.concat(data));
  client.end();

});