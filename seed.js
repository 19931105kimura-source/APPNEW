// src/seed.js
function seedProducts() {
  return [
    {
      productId: "p_1",
      name: "生ビール",
      price: 600,
      category: "drink",
      printTarget: "drink",
      isActive: true,
    },
    {
      productId: "p_2",
      name: "ハイボール",
      price: 550,
      category: "drink",
      printTarget: "drink",
      isActive: true,
    },
    {
      productId: "p_3",
      name: "唐揚げ",
      price: 700,
      category: "food",
      printTarget: "food",
      isActive: true,
    },
    {
      productId: "p_4",
      name: "枝豆",
      price: 400,
      category: "food",
      printTarget: "food",
      isActive: true,
    },
  ];
}

module.exports = {
  seedProducts,
};
