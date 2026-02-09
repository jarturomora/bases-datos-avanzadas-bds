from fastapi import APIRouter, HTTPException
from ..db import db, client
from ..models import OrderCreateIn
from datetime import datetime
import time

router = APIRouter(prefix="/api/orders", tags=["orders"])

@router.post("")
def create_order(payload: OrderCreateIn):
    customer = db.customers.find_one({"email": payload.customerEmail})
    if not customer:
        raise HTTPException(status_code=400, detail="Customer not found")

    if not payload.items:
        raise HTTPException(status_code=400, detail="Items required")

    now = datetime.utcnow()
    order_no = f"ORD-API-{int(time.time())}"

    lines = []
    subtotal = 0.0
    tax_total = 0.0

    for it in payload.items:
        p = db.products.find_one({"sku": it.sku, "active": True})
        if not p:
            raise HTTPException(status_code=400, detail=f"Product not found: {it.sku}")

        qty = int(it.qty)
        line = float(p["price"]) * qty
        subtotal += line
        tax_total += line * float(p["tax"])

        lines.append({
            "sku": p["sku"],
            "name": p["name"],
            "qty": qty,
            "unitPrice": float(p["price"]),
            "taxRate": float(p["tax"]),
            "discount": 0.0
        })

    subtotal = round(subtotal, 2)
    tax_total = round(tax_total, 2)
    total = round(subtotal + tax_total, 2)

    order_doc = {
        "orderNo": order_no,
        "customerId": customer["_id"],
        "createdAt": now,
        "status": "paid",
        "channel": payload.channel,
        "items": lines,
        "totals": {"subtotal": subtotal, "tax": tax_total, "total": total},
        "payment": {**(payload.payment or {}), "paidAt": now}
    }

    # Transacción multi-documento: orders + inventory_movements
    with client.start_session() as session:
        session.start_transaction()
        try:
            db.orders.insert_one(order_doc, session=session)

            moves = [{
                "sku": ln["sku"],
                "type": "out",
                "qty": -ln["qty"],
                "ts": now,
                "ref": {"orderNo": order_no}
            } for ln in lines]

            db.inventory_movements.insert_many(moves, session=session)

            session.commit_transaction()
            return {"ok": True, "orderNo": order_no, "total": total}
        except Exception as e:
            session.abort_transaction()
            raise HTTPException(status_code=400, detail=str(e))
