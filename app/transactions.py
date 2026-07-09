from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from firebase_admin import firestore

# ❌ XÓA HOẶC BỎ dòng db = firestore.client() ở đây đi bạn nhé!

router = APIRouter(tags=["Transactions"])

# ==========================================
# --- SCHEMAS CHO GIAO DỊCH ---
# ==========================================
class TransactionCreate(BaseModel):
    userId: str
    walletId: str
    walletName: str
    categoryId: str
    categoryName: str
    categoryIcon: str
    amount: float = Field(gt=0, description="Số tiền phải lớn hơn 0")
    type: str
    date: datetime
    note: str

class TransactionUpdate(BaseModel):
    walletId: Optional[str] = None
    walletName: Optional[str] = None
    categoryId: Optional[str] = None
    categoryName: Optional[str] = None
    categoryIcon: Optional[str] = None
    amount: Optional[float] = Field(default=None, gt=0, description="Số tiền phải lớn hơn 0")
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
        db = firestore.client()
        
        # Kiểm tra ví có tồn tại không
        wallet_ref = db.collection('wallets').document(transaction.walletId)
        wallet_doc = wallet_ref.get()
        if not wallet_doc.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy ví được gán")
        
        # Tính số dư mới
        wallet_data = wallet_doc.to_dict()
        current_balance = wallet_data.get('balance', 0)
        if transaction.type == "Chi":
            new_balance = current_balance - transaction.amount
        elif transaction.type == "Thu":
            new_balance = current_balance + transaction.amount
        else:
            new_balance = current_balance
            
        doc_ref = db.collection('transactions').document()
        data = transaction.dict()
        data['id'] = doc_ref.id
        
        # Ghi đồng thời giao dịch và cập nhật ví (dùng batch)
        batch = db.batch()
        batch.set(doc_ref, data)
        batch.update(wallet_ref, {'balance': new_balance})
        batch.commit()
        
        return {"status": "success", "message": "Đã thêm giao dịch và cập nhật số dư ví", "data": data}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 2. XEM TẤT CẢ GIAO DỊCH CỦA USER
@router.get("/transactions/user/{user_id}")
def get_user_transactions(user_id: str):
    try:
        db = firestore.client()
        transactions_ref = db.collection('transactions').where('userId', '==', user_id).stream()
        transactions_list = [doc.to_dict() for doc in transactions_ref]
        return {"status": "success", "total": len(transactions_list), "data": transactions_list}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 3. SỬA GIAO DỊCH
@router.put("/transactions/{transaction_id}")
def update_transaction(transaction_id: str, transaction: TransactionUpdate):
    try:
        db = firestore.client()
        doc_ref = db.collection('transactions').document(transaction_id)
        doc = doc_ref.get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch này")
        
        old_data = doc.to_dict()
        old_wallet_id = old_data.get('walletId')
        old_amount = old_data.get('amount', 0)
        old_type = old_data.get('type')
        
        update_data = {k: v for k, v in transaction.dict().items() if v is not None}
        if not update_data:
            return {"status": "success", "message": "Không có gì thay đổi", "data": old_data}
            
        new_wallet_id = update_data.get('walletId', old_wallet_id)
        new_amount = update_data.get('amount', old_amount)
        new_type = update_data.get('type', old_type)
        
        batch = db.batch()
        
        # Nếu đổi ví hoặc đổi tiền/loại giao dịch -> Cập nhật số dư ví
        if old_wallet_id == new_wallet_id:
            # Cùng ví: Hoàn tác lượng cũ, áp dụng lượng mới
            wallet_ref = db.collection('wallets').document(old_wallet_id)
            wallet_doc = wallet_ref.get()
            if wallet_doc.exists:
                balance = wallet_doc.to_dict().get('balance', 0)
                # Hoàn tác
                if old_type == "Chi":
                    balance += old_amount
                elif old_type == "Thu":
                    balance -= old_amount
                
                # Áp dụng mới
                if new_type == "Chi":
                    balance -= new_amount
                elif new_type == "Thu":
                    balance += new_amount
                
                batch.update(wallet_ref, {'balance': balance})
        else:
            # Khác ví: Hoàn tác ví cũ, trừ/cộng ví mới
            # 1. Ví cũ
            old_wallet_ref = db.collection('wallets').document(old_wallet_id)
            old_wallet_doc = old_wallet_ref.get()
            if old_wallet_doc.exists:
                old_balance = old_wallet_doc.to_dict().get('balance', 0)
                if old_type == "Chi":
                    old_balance += old_amount
                elif old_type == "Thu":
                    old_balance -= old_amount
                batch.update(old_wallet_ref, {'balance': old_balance})
                
            # 2. Ví mới
            new_wallet_ref = db.collection('wallets').document(new_wallet_id)
            new_wallet_doc = new_wallet_ref.get()
            if new_wallet_doc.exists:
                new_balance = new_wallet_doc.to_dict().get('balance', 0)
                if new_type == "Chi":
                    new_balance -= new_amount
                elif new_type == "Thu":
                    new_balance += new_amount
                batch.update(new_wallet_ref, {'balance': new_balance})
                
        batch.update(doc_ref, update_data)
        batch.commit()
        
        return {"status": "success", "message": "Đã cập nhật giao dịch và đồng bộ số dư ví", "data": doc_ref.get().to_dict()}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 4. XÓA GIAO DỊCH
@router.delete("/transactions/{transaction_id}")
def delete_transaction(transaction_id: str):
    try:
        db = firestore.client()
        doc_ref = db.collection('transactions').document(transaction_id)
        doc = doc_ref.get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch này")
            
        t_data = doc.to_dict()
        wallet_id = t_data.get('walletId')
        amount = t_data.get('amount', 0)
        t_type = t_data.get('type')
        
        wallet_ref = db.collection('wallets').document(wallet_id)
        wallet_doc = wallet_ref.get()
        
        batch = db.batch()
        if wallet_doc.exists:
            current_balance = wallet_doc.to_dict().get('balance', 0)
            if t_type == "Chi":
                new_balance = current_balance + amount
            elif t_type == "Thu":
                new_balance = current_balance - amount
            else:
                new_balance = current_balance
            batch.update(wallet_ref, {'balance': new_balance})
            
        batch.delete(doc_ref)
        batch.commit()
        
        return {"status": "success", "message": f"Đã xóa giao dịch và hoàn lại {amount} vào ví"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))