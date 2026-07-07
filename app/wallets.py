from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from firebase_admin import firestore

router = APIRouter(tags=["Wallets"])

# ==========================================
# --- SCHEMAS CHO VÍ ---
# ==========================================

class WalletCreate(BaseModel):
    userId: str
    name: str
    type: str
    balance: int

class WalletUpdate(BaseModel):
    name: Optional[str] = None
    type: Optional[str] = None
    balance: Optional[int] = None

class WalletTransfer(BaseModel):
    userId: str
    fromWalletId: str
    toWalletId: str
    amount: int

# ==========================================
# --- CÁC API QUẢN LÝ VÍ ---
# ==========================================

# 1. TẠO VÍ MỚI
@router.post("/wallets/")
def create_wallet(wallet: WalletCreate):
    try:
        db = firestore.client()
        doc_ref = db.collection('wallets').document()
        data = wallet.dict()
        data['id'] = doc_ref.id
        doc_ref.set(data)
        return {"status": "success", "message": "Đã tạo Ví", "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 2. LẤY DANH SÁCH VÍ CỦA USER
@router.get("/wallets/user/{user_id}")
def get_user_wallets(user_id: str):
    try:
        db = firestore.client()
        wallets_ref = db.collection('wallets').where('userId', '==', user_id).stream()
        wallets_list = [doc.to_dict() for doc in wallets_ref]
        return {"status": "success", "total": len(wallets_list), "data": wallets_list}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 3. LẤY THÔNG TIN 1 VÍ
@router.get("/wallets/{wallet_id}")
def get_wallet(wallet_id: str):
    try:
        db = firestore.client()
        doc = db.collection('wallets').document(wallet_id).get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy ví này")
        return {"status": "success", "data": doc.to_dict()}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 4. CẬP NHẬT VÍ
@router.put("/wallets/{wallet_id}")
def update_wallet(wallet_id: str, wallet: WalletUpdate):
    try:
        db = firestore.client()
        doc_ref = db.collection('wallets').document(wallet_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy ví này")

        update_data = {k: v for k, v in wallet.dict().items() if v is not None}
        if update_data:
            doc_ref.update(update_data)

        return {"status": "success", "message": "Đã cập nhật ví", "data": doc_ref.get().to_dict()}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 5. XÓA VÍ
@router.delete("/wallets/{wallet_id}")
def delete_wallet(wallet_id: str):
    try:
        db = firestore.client()
        doc_ref = db.collection('wallets').document(wallet_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy ví này")

        doc_ref.delete()
        return {"status": "success", "message": f"Đã xóa ví {wallet_id}"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 6. CHUYỂN TIỀN GIỮA CÁC VÍ
@router.post("/wallets/transfer/")
def transfer_between_wallets(transfer: WalletTransfer):
    try:
        db = firestore.client()
        from_ref = db.collection('wallets').document(transfer.fromWalletId)
        to_ref = db.collection('wallets').document(transfer.toWalletId)

        from_doc = from_ref.get()
        to_doc = to_ref.get()

        if not from_doc.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy ví nguồn")
        if not to_doc.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy ví đích")

        from_balance = from_doc.to_dict().get('balance', 0)
        if from_balance < transfer.amount:
            raise HTTPException(status_code=400, detail="Số dư ví nguồn không đủ")

        # Dùng batch để đảm bảo cả 2 thao tác cùng thành công hoặc cùng thất bại
        batch = db.batch()
        batch.update(from_ref, {'balance': from_balance - transfer.amount})
        batch.update(to_ref, {'balance': to_doc.to_dict().get('balance', 0) + transfer.amount})
        batch.commit()

        return {
            "status": "success",
            "message": f"Đã chuyển {transfer.amount} từ ví nguồn sang ví đích"
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
