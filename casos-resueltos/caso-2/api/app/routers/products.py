from fastapi import APIRouter, HTTPException
from ..db import db
from ..models import ProductIn

router = APIRouter(prefix="/api/products", tags=["products"])

@router.post("")
def create_product(p: ProductIn):
    try:
        db.products.insert_one(p.model_dump(exclude_none=True))
        return {"ok": True, "sku": p.sku}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("")
def list_products(category: str | None = None, minPrice: float | None = None, maxPrice: float | None = None):
    q: dict = {"active": True}
    if category:
        q["category"] = category
    if minPrice is not None or maxPrice is not None:
        q["price"] = {}
        if minPrice is not None:
            q["price"]["$gte"] = float(minPrice)
        if maxPrice is not None:
            q["price"]["$lte"] = float(maxPrice)

    return list(db.products.find(q, {"_id": 0}).limit(200))

@router.get("/{sku}")
def get_product(sku: str):
    p = db.products.find_one({"sku": sku}, {"_id": 0})
    if not p:
        raise HTTPException(status_code=404, detail="Not found")
    return p

@router.patch("/{sku}")
def patch_product(sku: str, payload: dict):
    # payload ejemplo: {"price": 9.25, "tagsAdd": ["nuevo"], "active": false}
    update: dict = {"$set": {}, "$addToSet": {}}

    if "price" in payload:
        update["$set"]["price"] = float(payload["price"])
    if "active" in payload:
        update["$set"]["active"] = bool(payload["active"])

    if "tagsAdd" in payload and isinstance(payload["tagsAdd"], list) and payload["tagsAdd"]:
        update["$addToSet"]["tags"] = {"$each": payload["tagsAdd"]}

    update = {k: v for k, v in update.items() if v}
    if not update:
        raise HTTPException(status_code=400, detail="No valid fields to update")

    res = db.products.update_one({"sku": sku}, update)
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Not found")
    return {"ok": True}

@router.delete("/{sku}")
def soft_delete_product(sku: str):
    res = db.products.update_one({"sku": sku}, {"$set": {"active": False}})
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="Not found")
    return {"ok": True}
