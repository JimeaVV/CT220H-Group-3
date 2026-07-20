from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Literal, Optional

from fastapi import APIRouter, HTTPException
from firebase_admin import firestore
from pydantic import BaseModel, Field

VN_TZ = timezone(timedelta(hours=7))
router = APIRouter(tags=["Transactions"])


class TransactionCreate(BaseModel):
    userId: str = Field(min_length=1)
    walletId: str = Field(min_length=1)
    walletName: str = ""
    categoryId: str = Field(min_length=1)
    categoryName: str = ""
    categoryIcon: str = ""
    amount: float = Field(gt=0, description="Số tiền phải lớn hơn 0")
    type: Literal["Thu", "Chi"]
    date: datetime
    note: str = Field(default="", max_length=500)


class TransactionUpdate(BaseModel):
    walletId: Optional[str] = Field(default=None, min_length=1)
    walletName: Optional[str] = None
    categoryId: Optional[str] = Field(default=None, min_length=1)
    categoryName: Optional[str] = None
    categoryIcon: Optional[str] = None
    amount: Optional[float] = Field(default=None, gt=0)
    type: Optional[Literal["Thu", "Chi"]] = None
    date: Optional[datetime] = None
    note: Optional[str] = Field(default=None, max_length=500)


def _model_dump(model: BaseModel, *, exclude_none: bool = False) -> dict:
    if hasattr(model, "model_dump"):
        return model.model_dump(exclude_none=exclude_none)
    return model.dict(exclude_none=exclude_none)


def _money(value: float) -> float:
    return round(float(value), 2)


def _normalize_datetime(value: datetime) -> datetime:
    if value.tzinfo is None:
        value = value.replace(tzinfo=VN_TZ)
    return value.astimezone(timezone.utc)


def _effect(transaction_type: str, amount: float) -> float:
    return amount if transaction_type == "Thu" else -amount


def _validate_wallet(wallet_data: dict, user_id: str) -> None:
    if wallet_data.get("userId") != user_id:
        raise HTTPException(status_code=403, detail="Ví không thuộc người dùng hiện tại")


def _validate_category(category_data: dict, user_id: str, transaction_type: str) -> None:
    owner_id = category_data.get("userId", "")
    if owner_id not in ("", user_id):
        raise HTTPException(status_code=403, detail="Danh mục không thuộc người dùng hiện tại")
    if category_data.get("type") != transaction_type:
        raise HTTPException(
            status_code=400,
            detail=f"Danh mục phải thuộc loại {transaction_type}",
        )


@router.post("/transactions/")
def create_transaction(transaction: TransactionCreate):
    try:
        db = firestore.client()
        wallet_ref = db.collection("wallets").document(transaction.walletId)
        category_ref = db.collection("categories").document(transaction.categoryId)
        transaction_ref = db.collection("transactions").document()
        db_transaction = db.transaction()

        @firestore.transactional
        def apply_create(tx):
            wallet_doc = wallet_ref.get(transaction=tx)
            category_doc = category_ref.get(transaction=tx)

            if not wallet_doc.exists:
                raise HTTPException(status_code=404, detail="Không tìm thấy ví được chọn")
            if not category_doc.exists:
                raise HTTPException(status_code=404, detail="Không tìm thấy danh mục được chọn")

            wallet_data = wallet_doc.to_dict()
            category_data = category_doc.to_dict()
            user_id = transaction.userId.strip()
            _validate_wallet(wallet_data, user_id)
            _validate_category(category_data, user_id, transaction.type)

            amount = _money(transaction.amount)
            current_balance = _money(wallet_data.get("balance", 0))
            new_balance = _money(current_balance + _effect(transaction.type, amount))
            if new_balance < 0:
                raise HTTPException(
                    status_code=400,
                    detail=(
                        "Số dư ví không đủ. "
                        f"Ví hiện có {current_balance:g}, giao dịch cần {amount:g}."
                    ),
                )

            data = _model_dump(transaction)
            data.update(
                {
                    "id": transaction_ref.id,
                    "userId": user_id,
                    "walletName": wallet_data.get("name", ""),
                    "categoryName": category_data.get("name", ""),
                    "categoryIcon": category_data.get("icon", ""),
                    "amount": amount,
                    "date": _normalize_datetime(transaction.date),
                    "note": transaction.note.strip(),
                }
            )

            tx.set(transaction_ref, data)
            tx.update(wallet_ref, {"balance": new_balance})
            return data

        data = apply_create(db_transaction)
        return {
            "status": "success",
            "message": "Đã thêm giao dịch và cập nhật số dư ví",
            "data": data,
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/transactions/user/{user_id}")
def get_user_transactions(user_id: str):
    try:
        db = firestore.client()
        items = []
        for doc in db.collection("transactions").where("userId", "==", user_id).stream():
            data = doc.to_dict()
            data.setdefault("id", doc.id)
            items.append(data)

        def sort_date(item: dict) -> datetime:
            value = item.get("date")
            if isinstance(value, datetime):
                return _normalize_datetime(value)
            return datetime.min.replace(tzinfo=timezone.utc)

        items.sort(key=sort_date, reverse=True)
        return {"status": "success", "total": len(items), "data": items}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.put("/transactions/{transaction_id}")
def update_transaction(transaction_id: str, transaction: TransactionUpdate):
    try:
        db = firestore.client()
        transaction_ref = db.collection("transactions").document(transaction_id)
        requested_changes = _model_dump(transaction, exclude_none=True)
        if "date" in requested_changes:
            requested_changes["date"] = _normalize_datetime(requested_changes["date"])
        if "amount" in requested_changes:
            requested_changes["amount"] = _money(requested_changes["amount"])
        if "note" in requested_changes:
            requested_changes["note"] = requested_changes["note"].strip()

        db_transaction = db.transaction()

        @firestore.transactional
        def apply_update(tx):
            current_doc = transaction_ref.get(transaction=tx)
            if not current_doc.exists:
                raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch")

            old_data = current_doc.to_dict()
            if not requested_changes:
                return old_data

            user_id = old_data.get("userId", "")
            old_wallet_id = old_data.get("walletId")
            new_wallet_id = requested_changes.get("walletId", old_wallet_id)
            old_category_id = old_data.get("categoryId")
            new_category_id = requested_changes.get("categoryId", old_category_id)
            old_type = old_data.get("type")
            new_type = requested_changes.get("type", old_type)
            old_amount = _money(old_data.get("amount", 0))
            new_amount = _money(requested_changes.get("amount", old_amount))

            old_wallet_ref = db.collection("wallets").document(old_wallet_id)
            new_wallet_ref = db.collection("wallets").document(new_wallet_id)
            category_ref = db.collection("categories").document(new_category_id)

            old_wallet_doc = old_wallet_ref.get(transaction=tx)
            if not old_wallet_doc.exists:
                raise HTTPException(
                    status_code=409,
                    detail="Ví cũ của giao dịch không còn tồn tại; không thể đồng bộ số dư",
                )

            if new_wallet_id == old_wallet_id:
                new_wallet_doc = old_wallet_doc
            else:
                new_wallet_doc = new_wallet_ref.get(transaction=tx)
                if not new_wallet_doc.exists:
                    raise HTTPException(status_code=404, detail="Không tìm thấy ví mới")

            category_doc = category_ref.get(transaction=tx)
            if not category_doc.exists:
                raise HTTPException(status_code=404, detail="Không tìm thấy danh mục mới")

            old_wallet_data = old_wallet_doc.to_dict()
            new_wallet_data = new_wallet_doc.to_dict()
            category_data = category_doc.to_dict()
            _validate_wallet(old_wallet_data, user_id)
            _validate_wallet(new_wallet_data, user_id)
            _validate_category(category_data, user_id, new_type)

            if old_wallet_id == new_wallet_id:
                balance = _money(old_wallet_data.get("balance", 0))
                balance_without_old = _money(balance - _effect(old_type, old_amount))
                final_balance = _money(balance_without_old + _effect(new_type, new_amount))
                if final_balance < 0:
                    raise HTTPException(status_code=400, detail="Số dư ví không đủ cho thay đổi này")
                tx.update(old_wallet_ref, {"balance": final_balance})
            else:
                old_balance = _money(old_wallet_data.get("balance", 0))
                restored_old_balance = _money(old_balance - _effect(old_type, old_amount))

                new_balance = _money(new_wallet_data.get("balance", 0))
                final_new_balance = _money(new_balance + _effect(new_type, new_amount))
                if final_new_balance < 0:
                    raise HTTPException(status_code=400, detail="Số dư ví mới không đủ")

                tx.update(old_wallet_ref, {"balance": restored_old_balance})
                tx.update(new_wallet_ref, {"balance": final_new_balance})

            final_changes = dict(requested_changes)
            final_changes.update(
                {
                    "walletId": new_wallet_id,
                    "walletName": new_wallet_data.get("name", ""),
                    "categoryId": new_category_id,
                    "categoryName": category_data.get("name", ""),
                    "categoryIcon": category_data.get("icon", ""),
                    "amount": new_amount,
                    "type": new_type,
                }
            )
            tx.update(transaction_ref, final_changes)
            return {**old_data, **final_changes}

        updated = apply_update(db_transaction)
        message = "Không có gì thay đổi" if not requested_changes else "Đã cập nhật giao dịch"
        return {"status": "success", "message": message, "data": updated}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.delete("/transactions/{transaction_id}")
def delete_transaction(transaction_id: str):
    try:
        db = firestore.client()
        transaction_ref = db.collection("transactions").document(transaction_id)
        db_transaction = db.transaction()

        @firestore.transactional
        def apply_delete(tx):
            transaction_doc = transaction_ref.get(transaction=tx)
            if not transaction_doc.exists:
                raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch")

            data = transaction_doc.to_dict()
            wallet_id = data.get("walletId")
            wallet_ref = db.collection("wallets").document(wallet_id)
            wallet_doc = wallet_ref.get(transaction=tx)
            if not wallet_doc.exists:
                raise HTTPException(
                    status_code=409,
                    detail="Ví của giao dịch không còn tồn tại; không thể hoàn tác số dư",
                )

            wallet_data = wallet_doc.to_dict()
            _validate_wallet(wallet_data, data.get("userId", ""))
            amount = _money(data.get("amount", 0))
            current_balance = _money(wallet_data.get("balance", 0))
            restored_balance = _money(current_balance - _effect(data.get("type"), amount))
            if restored_balance < 0:
                raise HTTPException(
                    status_code=409,
                    detail="Dữ liệu số dư ví không hợp lệ; không thể xóa giao dịch an toàn",
                )

            tx.update(wallet_ref, {"balance": restored_balance})
            tx.delete(transaction_ref)
            return amount

        amount = apply_delete(db_transaction)
        return {
            "status": "success",
            "message": f"Đã xóa giao dịch và hoàn tác {amount:g} trong ví",
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
