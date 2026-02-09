from pydantic import BaseModel, Field
from typing import List, Optional, Literal

Category = Literal["fruta","verdura","lacteos","panaderia","despensa","bebidas","higiene"]
Channel = Literal["store","web","subscription"]

class ProductIn(BaseModel):
    sku: str = Field(min_length=3)
    name: str
    category: Category
    tags: List[str] = []
    price: float = Field(ge=0)
    tax: float = Field(ge=0, le=0.25)
    isOrganic: bool = True
    active: bool = True
    origin: Optional[dict] = None
    nutrition: Optional[dict] = None

class OrderItemIn(BaseModel):
    sku: str
    qty: int = Field(ge=1)

class OrderCreateIn(BaseModel):
    customerEmail: str
    channel: Channel = "web"
    items: List[OrderItemIn]
    payment: Optional[dict] = {"method": "card"}
