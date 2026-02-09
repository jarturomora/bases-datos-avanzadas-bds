from fastapi import FastAPI
from .routers.products import router as products_router
from .routers.orders import router as orders_router
from .routers.analytics import router as analytics_router

app = FastAPI(title="API CRUD y analítica de ventas con MongoDB (Eco Store)")

@app.get("/health")
def health():
    return {"ok": True}

app.include_router(products_router)
app.include_router(orders_router)
app.include_router(analytics_router)