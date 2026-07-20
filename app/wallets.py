from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, HTTPException
from firebase_admin import firestore
from pydantic import BaseModel, Field

router = APIRouter(tags=["Wallets"])


class WalletCreate(BaseModel):
    userId: str = Field(min_length=1)
    name: str = Field(min_length=1, max_length=80)
    type: str = Field(min_length=1, max_length=40)
    balance: float = Field(ge=0, description="Số dư không được âm")


class WalletUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=80)
    type: Optional[str] = Field(default=None, min_length=1, max_length=40)
    balance: Optional[float] = Field(default=None, ge=0, description="Số dư không được âm")


class WalletTransfer(BaseModel):
    userId: str = Field(min_length=1)
    fromWalletId: str = Field(min_length=1)
    toWalletId: str = Field(min_length=1)
    amount: float = Field(gt=0, description="Số tiền chuyển phải lớn hơn 0")


def _model_dump(model: BaseModel, *, exclude_none: bool = False) -> dict:
    if hasattr(model, "model_dump"):
        return model.model_dump(exclude_none=exclude_none)
    return model.dict(exclude_none=exclude_none)


def _money(value: float) -> float:
    return round(float(value), 2)


def _sync_wallet_name(db, wallet_id: str, wallet_name: str) -> None:
    batch = db.batch()
    operations = 0
    for collection_name in ("transactions", "recurring_transactions"):
        docs = db.collection(collection_name).where("walletId", "==", wallet_id).stream()
        for doc in docs:
            batch.update(doc.reference, {"walletName": wallet_name})
            operations += 1
            if operations >= 450:
                batch.commit()
                batch = db.batch()
                operations = 0
    if operations:
        batch.commit()


def _wallet_is_referenced(db, wallet_id: str) -> bool:
    for collection_name in ("transactions", "recurring_transactions"):
        found = list(
            db.collection(collection_name)
            .where("walletId", "==", wallet_id)
            .limit(1)
            .stream()
        )
        if found:
            return True
    return False


@router.post("/wallets/")
def create_wallet(wallet: WalletCreate):
    try:
        db = firestore.client()
        name = " ".join(wallet.name.strip().split())
        wallet_type = wallet.type.strip()
        if not name or not wallet_type:
            raise HTTPException(status_code=422, detail="Tên và loại ví không được để trống")

        doc_ref = db.collection("wallets").document()
        data = _model_dump(wallet)
        data.update(
            {
                "id": doc_ref.id,
                "userId": wallet.userId.strip(),
                "name": name,
                "type": wallet_type,
                "balance": _money(wallet.balance),
            }
        )
        doc_ref.set(data)
        return {"status": "success", "message": "Đã tạo ví", "data": data}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/wallets/user/{user_id}")
def get_user_wallets(user_id: str):
    try:
        db = firestore.client()
        wallets = []
        for doc in db.collection("wallets").where("userId", "==", user_id).stream():
            data = doc.to_dict()
            data.setdefault("id", doc.id)
            wallets.append(data)
        wallets.sort(key=lambda item: item.get("name", "").casefold())
        return {"status": "success", "total": len(wallets), "data": wallets}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/wallets/{wallet_id}")
def get_wallet(wallet_id: str):
    try:
        snapshot = firestore.client().collection("wallets").document(wallet_id).get()
        if not snapshot.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy ví")
        return {"status": "success", "data": snapshot.to_dict()}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.put("/wallets/{wallet_id}")
def update_wallet(wallet_id: str, wallet: WalletUpdate):
    try:
        db = firestore.client()
        wallet_ref = db.collection("wallets").document(wallet_id)
        update_data = _model_dump(wallet, exclude_none=True)
        if not update_data:
            snapshot = wallet_ref.get()
            if not snapshot.exists:
                raise HTTPException(status_code=404, detail="Không tìm thấy ví")
            return {"status": "success", "message": "Không có gì thay đổi", "data": snapshot.to_dict()}

        if "name" in update_data:
            update_data["name"] = " ".join(update_data["name"].strip().split())
            if not update_data["name"]:
                raise HTTPException(status_code=422, detail="Tên ví không được để trống")
        if "type" in update_data:
            update_data["type"] = update_data["type"].strip()
            if not update_data["type"]:
                raise HTTPException(status_code=422, detail="Loại ví không được để trống")
        if "balance" in update_data:
            update_data["balance"] = _money(update_data["balance"])

        transaction = db.transaction()

        @firestore.transactional
        def apply_update(db_transaction):
            snapshot = wallet_ref.get(transaction=db_transaction)
            if not snapshot.exists:
                raise HTTPException(status_code=404, detail="Không tìm thấy ví")
            db_transaction.update(wallet_ref, update_data)
            return {**snapshot.to_dict(), **update_data}

        updated = apply_update(transaction)
        if "name" in update_data:
            _sync_wallet_name(db, wallet_id, update_data["name"])

        return {"status": "success", "message": "Đã cập nhật ví", "data": updated}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.delete("/wallets/{wallet_id}")
def delete_wallet(wallet_id: str):
    try:
        db = firestore.client()
        wallet_ref = db.collection("wallets").document(wallet_id)
        if not wallet_ref.get().exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy ví")
        if _wallet_is_referenced(db, wallet_id):
            raise HTTPException(
                status_code=409,
                detail="Ví đang có giao dịch hoặc giao dịch lặp. Hãy xóa/chuyển dữ liệu trước.",
            )

        wallet_ref.delete()
        return {"status": "success", "message": "Đã xóa ví"}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/wallets/transfer/")
def transfer_between_wallets(transfer: WalletTransfer):
    if transfer.fromWalletId == transfer.toWalletId:
        raise HTTPException(status_code=400, detail="Ví nguồn và ví đích phải khác nhau")

    try:
        db = firestore.client()
        from_ref = db.collection("wallets").document(transfer.fromWalletId)
        to_ref = db.collection("wallets").document(transfer.toWalletId)
        amount = _money(transfer.amount)
        owner_id = transfer.userId.strip()
        transaction = db.transaction()

        @firestore.transactional
        def apply_transfer(db_transaction):
            from_doc = from_ref.get(transaction=db_transaction)
            to_doc = to_ref.get(transaction=db_transaction)

            if not from_doc.exists:
                raise HTTPException(status_code=404, detail="Không tìm thấy ví nguồn")
            if not to_doc.exists:
                raise HTTPException(status_code=404, detail="Không tìm thấy ví đích")

            from_data = from_doc.to_dict()
            to_data = to_doc.to_dict()
            if from_data.get("userId") != owner_id or to_data.get("userId") != owner_id:
                raise HTTPException(status_code=403, detail="Ví không thuộc người dùng hiện tại")

            from_balance = _money(from_data.get("balance", 0))
            to_balance = _money(to_data.get("balance", 0))
            if from_balance < amount:
                raise HTTPException(status_code=400, detail="Số dư ví nguồn không đủ")

            db_transaction.update(from_ref, {"balance": _money(from_balance - amount)})
            db_transaction.update(to_ref, {"balance": _money(to_balance + amount)})

        apply_transfer(transaction)
        return {"status": "success", "message": f"Đã chuyển {amount:g} giữa hai ví"}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
