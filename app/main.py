import firebase_admin
from firebase_admin import credentials, firestore
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from app.transactions import router as transaction_router
from app.categories import router as category_router
from app.reports import router as report_router


# --- 1. KHỞI TẠO FIREBASE ADMIN (Đã sửa lỗi chống trùng lặp khi Reload) ---
cred = credentials.Certificate("serviceAccountKey.json")
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

# --- 2. KHỞI TẠO FASTAPI ---
app = FastAPI(title="Backend Quản Lý Chi Tiêu - Đồ án Flutter")


# --- 3. KẾT NỐI BỘ API GIAO DỊCH TỪ FILE RIÊNG (Đã bổ sung) ---
from app.transactions import router as transaction_router
app.include_router(transaction_router)
app.include_router(category_router)
app.include_router(report_router)


# ==========================================
# --- 4. ĐỊNH NGHĨA SCHEMAS (PYDANTIC MODELS)
# ==========================================

class UserCreate(BaseModel):
    email: str
    displayName: str

class WalletCreate(BaseModel):
    userId: str
    name: str
    type: str
    balance: int

class CategoryCreate(BaseModel):
    userId: Optional[str] = "" 
    name: str
    type: str 
    icon: str

# LƯU Ý: Class TransactionCreate đã được chuyển hẳn sang file transactions.py 
# nên ở main.py chúng ta có thể xóa đi cho đỡ rối code.

class BudgetCreate(BaseModel):
    userId: str
    categoryId: str
    amountLimit: int
    month: int
    year: int

class RecurringTransactionCreate(BaseModel):
    userId: str
    walletId: str
    walletName: str
    categoryId: str
    categoryName: str
    categoryIcon: str
    amount: int
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

# 2. API Tạo Ví (Wallet)
@app.post("/wallets/", tags=["Wallets"])
def create_wallet(wallet: WalletCreate):  # Đổi từ async def -> def
    try:
        doc_ref = db.collection('wallets').document()
        data = wallet.dict()
        data['id'] = doc_ref.id
        doc_ref.set(data)
        return {"status": "success", "message": "Đã tạo Ví", "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 3. API Tạo Danh mục (Category)
@app.post("/categories/", tags=["Categories"])
def create_category(category: CategoryCreate):  # Đổi từ async def -> def
    try:
        doc_ref = db.collection('categories').document()
        data = category.dict()
        data['id'] = doc_ref.id
        doc_ref.set(data)
        return {"status": "success", "message": "Đã tạo Danh mục", "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 4. API Tạo Ngân sách (Budget)
@app.post("/budgets/", tags=["Budgets"])
def create_budget(budget: BudgetCreate):  # Đổi từ async def -> def
    try:
        doc_ref = db.collection('budgets').document()
        data = budget.dict()
        data['id'] = doc_ref.id
        doc_ref.set(data)
        return {"status": "success", "message": "Đã tạo Ngân sách", "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 5. API Tạo Giao dịch lặp lại (Recurring Transaction)
@app.post("/recurring_transactions/", tags=["Recurring Transactions"])
def create_recurring_transaction(recurring: RecurringTransactionCreate):  # Đổi từ async def -> def
    try:
        doc_ref = db.collection('recurring_transactions').document()
        data = recurring.dict()
        data['id'] = doc_ref.id
        doc_ref.set(data)
        return {"status": "success", "message": "Đã thiết lập Giao dịch lặp lại", "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))