db = db.getSiblingDB("eco_store");

db.products.drop();
db.customers.drop();
db.orders.drop();
db.inventory_movements.drop();

// Tipos numéricos aceptados para importes
const MONEY_TYPES = ["int", "long", "double", "decimal"];

db.createCollection("products", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["sku", "name", "category", "price", "tax", "isOrganic", "active"],
      properties: {
        sku: { bsonType: "string", minLength: 3 },
        name: { bsonType: "string" },
        category: { enum: ["fruta", "verdura", "lacteos", "panaderia", "despensa", "bebidas", "higiene"] },
        tags: { bsonType: "array", items: { bsonType: "string" } },

        // ✅ antes: double estricto
        price: { bsonType: MONEY_TYPES, minimum: 0 },
        tax: { bsonType: MONEY_TYPES, minimum: 0, maximum: 0.25 },

        isOrganic: { bsonType: "bool" },
        origin: {
          bsonType: "object",
          properties: {
            country: { bsonType: "string" },
            region: { bsonType: "string" },
            farm: { bsonType: "string" }
          },
          additionalProperties: true
        },
        nutrition: { bsonType: "object" }, // flexible
        active: { bsonType: "bool" }
      },
      additionalProperties: true
    }
  },
  validationLevel: "strict",
  validationAction: "error"
});

db.createCollection("customers", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["email", "name", "createdAt"],
      properties: {
        email: { bsonType: "string", pattern: "@" },
        name: { bsonType: "string" },
        phone: { bsonType: "string" },
        loyalty: {
          bsonType: "object",
          properties: {
            level: { enum: ["bronze", "silver", "gold"] },
            points: { bsonType: "int", minimum: 0 }
          },
          additionalProperties: true
        },
        addresses: { bsonType: "array" },
        createdAt: { bsonType: "date" }
      },
      additionalProperties: true
    }
  }
});

db.createCollection("orders", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["orderNo", "customerId", "createdAt", "status", "items", "totals", "channel"],
      properties: {
        orderNo: { bsonType: "string" },
        customerId: { bsonType: "objectId" },
        createdAt: { bsonType: "date" },
        status: { enum: ["created", "paid", "shipped", "cancelled"] },
        channel: { enum: ["store", "web", "subscription"] },

        items: {
          bsonType: "array",
          minItems: 1,
          items: {
            bsonType: "object",
            required: ["sku", "name", "qty", "unitPrice", "taxRate"],
            properties: {
              sku: { bsonType: "string" },
              name: { bsonType: "string" },
              qty: { bsonType: "int", minimum: 1 },

              // ✅ antes: double estricto
              unitPrice: { bsonType: MONEY_TYPES, minimum: 0 },
              taxRate: { bsonType: MONEY_TYPES, minimum: 0, maximum: 0.25 },
              discount: { bsonType: MONEY_TYPES, minimum: 0 }
            },
            additionalProperties: true
          }
        },

        totals: {
          bsonType: "object",
          required: ["subtotal", "tax", "total"],
          properties: {
            // ✅ antes: double estricto
            subtotal: { bsonType: MONEY_TYPES, minimum: 0 },
            tax: { bsonType: MONEY_TYPES, minimum: 0 },
            total: { bsonType: MONEY_TYPES, minimum: 0 }
          },
          additionalProperties: true
        },

        payment: { bsonType: "object" } // flexible
      },
      additionalProperties: true
    }
  }
});

db.createCollection("inventory_movements", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["sku", "type", "qty", "ts", "ref"],
      properties: {
        sku: { bsonType: "string" },
        type: { enum: ["in", "out", "adjustment"] },
        qty: { bsonType: "int" },
        ts: { bsonType: "date" },
        ref: { bsonType: "object" }
      },
      additionalProperties: true
    }
  }
});
