import firebase_admin
from firebase_admin import credentials, firestore
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from app.transactions import router as transaction_router
from app.categories import router as category_router
from app.reports import router as report_router
from app.wallets import router as wallet_router
from app.budgets import router as budget_router
from app.recurring import router as recurring_router



# --- 1. KHỞI TẠO FIREBASE ADMIN (Đã sửa lỗi chống trùng lặp khi Reload) ---
cred = credentials.Certificate("serviceAccountKey.json")
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

# --- 2. KHỞI TẠO FASTAPI ---
app = FastAPI(title="Backend Quản Lý Chi Tiêu - Đồ án Flutter")


# --- 3. KẾT NỐI CÁC BỘ API TỪ FILE RIÊNG ---
from app.transactions import router as transaction_router
app.include_router(transaction_router)
app.include_router(category_router)
app.include_router(report_router)
app.include_router(wallet_router)
app.include_router(budget_router)
app.include_router(recurring_router)




# ==========================================
# --- 4. ĐỊNH NGHĨA SCHEMAS (PYDANTIC MODELS)
# ==========================================

class UserCreate(BaseModel):
    email: str
    displayName: str

class CategoryCreate(BaseModel):
    userId: Optional[str] = "" 
    name: str
    type: str 
    icon: str

# LƯU Ý: Class TransactionCreate đã được chuyển hẳn sang file transactions.py 
# nên ở main.py chúng ta có thể xóa đi cho đỡ rối code.

class RecurringTransactionCreate(BaseModel):
    userId: str
    walletId: str
    walletName: str
    categoryId: str
    categoryName: str
    categoryIcon: str
    amount: float = Field(gt=0, description="Số tiền phải lớn hơn 0")
    note: str
    cycle: str
    nextTriggerDate: datetime


# ==========================================
# --- 5. CÁC API ENDPOINTS (Đã đổi sang hàm 'def' thường để tối ưu Firebase)
# ==========================================

# 1. API Tạo User
@app.post("/users/{uid}", tags=["Users"])
def create_user(uid: str, user: UserCreate):
    try:
        user_data = user.dict()
        user_data['id'] = uid
        user_data['createdAt'] = firestore.SERVER_TIMESTAMP 
        db.collection('users').document(uid).set(user_data)
        
        user_data['createdAt'] = "Đã lưu thời gian hệ thống thành công"
        return {"status": "success", "message": "Đã tạo User", "data": user_data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

