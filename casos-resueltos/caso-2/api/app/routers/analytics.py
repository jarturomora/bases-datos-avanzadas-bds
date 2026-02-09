from fastapi import APIRouter
from ..db import db
from datetime import datetime, timedelta

router = APIRouter(prefix="/api/analytics", tags=["analytics"])

@router.get("/sales/daily")
def sales_daily(days: int = 30):
    start = datetime.utcnow() - timedelta(days=days)
    pipeline = [
        {"$match": {"status": {"$in": ["paid", "shipped"]}, "createdAt": {"$gte": start}}},
        {"$group": {
            "_id": {"$dateToString": {"format": "%Y-%m-%d", "date": "$createdAt"}},
            "orders": {"$sum": 1},
            "revenue": {"$sum": "$totals.total"},
            "avgTicket": {"$avg": "$totals.total"}
        }},
        {"$sort": {"_id": 1}}
    ]
    return list(db.orders.aggregate(pipeline))

@router.get("/top-products")
def top_products(limit: int = 10):
    pipeline = [
        {"$match": {"status": {"$in": ["paid", "shipped"]}}},
        {"$unwind": "$items"},
        {"$group": {
            "_id": {"sku": "$items.sku", "name": "$items.name"},
            "units": {"$sum": "$items.qty"},
            "revenue": {"$sum": {"$multiply": ["$items.qty", "$items.unitPrice"]}}
        }},
        {"$sort": {"units": -1}},
        {"$limit": limit}
    ]
    return list(db.orders.aggregate(pipeline))

@router.get("/sales/by-channel")
def sales_by_channel(months: int = 6):
    start = datetime.utcnow() - timedelta(days=30 * months)
    pipeline = [
        {"$match": {"status": {"$in": ["paid", "shipped"]}, "createdAt": {"$gte": start}}},
        {"$group": {
            "_id": {
                "channel": "$channel",
                "month": {"$dateToString": {"format": "%Y-%m", "date": "$createdAt"}}
            },
            "revenue": {"$sum": "$totals.total"},
            "orders": {"$sum": 1}
        }},
        {"$sort": {"_id.month": 1, "revenue": -1}}
    ]
    return list(db.orders.aggregate(pipeline))
