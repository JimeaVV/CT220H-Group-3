from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from firebase_admin import firestore

# ❌ XÓA HOẶC BỎ dòng db = firestore.client() ở đây đi bạn nhé!

router = APIRouter(tags=["Transactions"])

# ==========================================
# --- SCHEMAS CHO GIAO DỊCH (Giữ nguyên) ---
# ==========================================
class TransactionCreate(BaseModel):
    userId: str
    walletId: str
    walletName: str
    categoryId: str
    categoryName: str
    categoryIcon: str
    amount: int
    type: str
    date: datetime
    note: str

class TransactionUpdate(BaseModel):
    walletId: Optional[str] = None
    walletName: Optional[str] = None
    categoryId: Optional[str] = None
    categoryName: Optional[str] = None
    categoryIcon: Optional[str] = None
    amount: Optional[int] = None
    type: Optional[str] = None
    date: Optional[datetime] = None
    note: Optional[str] = None


# ==========================================
# --- CÁC API CRUD GIAO DỊCH (Thêm db vào trong) ---
# ==========================================

# 1. THÊM GIAO DỊCH
@router.post("/transactions/")
def create_transaction(transaction: TransactionCreate):
    try:
        db = firestore.client() # ⭐ ĐƯA VÀO ĐÂY: Chỉ chạy khi API này được gọi
        doc_ref = db.collection('transactions').document()
        data = transaction.dict()
        data['id'] = doc_ref.id
        doc_ref.set(data)
        return {"status": "success", "message": "Đã thêm giao dịch thành công", "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 2. XEM TẤT CẢ GIAO DỊCH CỦA USER
@router.get("/transactions/user/{user_id}")
def get_user_transactions(user_id: str):
    try:
        db = firestore.client() # ⭐ ĐƯA VÀO ĐÂY
        transactions_ref = db.collection('transactions').where('userId', '==', user_id).stream()
        transactions_list = []
        for doc in transactions_ref:
            transactions_list.append(doc.to_dict())
        return {"status": "success", "total": len(transactions_list), "data": transactions_list}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 3. SỬA GIAO DỊCH
@router.put("/transactions/{transaction_id}")
def update_transaction(transaction_id: str, transaction: TransactionUpdate):
    try:
        db = firestore.client() # ⭐ ĐƯA VÀO ĐÂY
        doc_ref = db.collection('transactions').document(transaction_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch này")
        
        update_data = {k: v for k, v in transaction.dict().items() if v is not None}
        if update_data:
            doc_ref.update(update_data)
            
        return {"status": "success", "message": "Đã cập nhật giao dịch", "data": doc_ref.get().to_dict()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 4. XÓA GIAO DỊCH
@router.delete("/transactions/{transaction_id}")
def delete_transaction(transaction_id: str):
    try:
        db = firestore.client() # ⭐ ĐƯA VÀO ĐÂY
        doc_ref = db.collection('transactions').document(transaction_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch này")
            
        doc_ref.delete()
        return {"status": "success", "message": f"Đã xóa thành công giao dịch {transaction_id}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))