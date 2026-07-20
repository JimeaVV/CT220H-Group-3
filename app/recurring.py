from __future__ import annotations

import calendar
from datetime import datetime, timedelta, timezone
from typing import Literal, Optional

from fastapi import APIRouter, HTTPException
from firebase_admin import firestore
from pydantic import BaseModel, Field

VN_TZ = timezone(timedelta(hours=7))
router = APIRouter(tags=["Recurring Transactions"])


class RecurringTransactionCreate(BaseModel):
    userId: str = Field(min_length=1)
    walletId: str = Field(min_length=1)
    walletName: str = ""
    categoryId: str = Field(min_length=1)
    categoryName: str = ""
    categoryIcon: str = ""
    amount: float = Field(gt=0)
    type: Literal["Thu", "Chi"]
    note: str = Field(default="", max_length=500)
    cycle: Literal["daily", "weekly", "monthly", "yearly"]
    nextTriggerDate: datetime
    isActive: bool = True


class RecurringTransactionUpdate(BaseModel):
    walletId: Optional[str] = Field(default=None, min_length=1)
    walletName: Optional[str] = None
    categoryId: Optional[str] = Field(default=None, min_length=1)
    categoryName: Optional[str] = None
    categoryIcon: Optional[str] = None
    amount: Optional[float] = Field(default=None, gt=0)
    type: Optional[Literal["Thu", "Chi"]] = None
    note: Optional[str] = Field(default=None, max_length=500)
    cycle: Optional[Literal["daily", "weekly", "monthly", "yearly"]] = None
    nextTriggerDate: Optional[datetime] = None
    isActive: Optional[bool] = None


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


def _to_datetime(value) -> datetime:
    if not isinstance(value, datetime):
        value = datetime.fromisoformat(value.isoformat())
    return _normalize_datetime(value)


def _validate_wallet_and_category(
    wallet_data: dict,
    category_data: dict,
    user_id: str,
    transaction_type: str,
) -> None:
    if wallet_data.get("userId") != user_id:
        raise HTTPException(status_code=403, detail="Ví không thuộc người dùng hiện tại")
    if category_data.get("userId", "") not in ("", user_id):
        raise HTTPException(status_code=403, detail="Danh mục không thuộc người dùng hiện tại")
    if category_data.get("type") != transaction_type:
        raise HTTPException(
            status_code=400,
            detail=f"Danh mục phải thuộc loại {transaction_type}",
        )


def calculate_next_trigger_date(current_date: datetime, cycle: str) -> datetime:
    current_date = _to_datetime(current_date)

    if cycle == "daily":
        return current_date + timedelta(days=1)
    if cycle == "weekly":
        return current_date + timedelta(weeks=1)
    if cycle == "monthly":
        month = current_date.month + 1
        year = current_date.year
        if month > 12:
            month = 1
            year += 1
        day = min(current_date.day, calendar.monthrange(year, month)[1])
        return current_date.replace(year=year, month=month, day=day)
    if cycle == "yearly":
        try:
            return current_date.replace(year=current_date.year + 1)
        except ValueError:
            return current_date.replace(year=current_date.year + 1, month=2, day=28)

    raise ValueError(f"Chu kỳ không hợp lệ: {cycle}")


def _next_future_trigger(current_date: datetime, cycle: str, now: datetime) -> datetime:
    """Tạo một giao dịch cho lần đến hạn và bỏ qua các kỳ đã lỡ quá lâu."""
    next_date = calculate_next_trigger_date(current_date, cycle)
    attempts = 0
    while next_date <= now and attempts < 1000:
        next_date = calculate_next_trigger_date(next_date, cycle)
        attempts += 1
    if attempts >= 1000:
        raise ValueError("Không thể tính ngày kích hoạt tiếp theo")
    return next_date


def process_recurring_transactions():
    """
    Xử lý các cấu hình đang hoạt động và đã đến hạn.

    Mỗi cấu hình được chạy trong Firestore transaction để tránh tạo trùng khi
    scheduler và nút "Chạy ngay" hoạt động cùng lúc.
    """
    db = firestore.client()
    now = datetime.now(timezone.utc)

    # Chỉ lọc isActive trên Firestore, còn thời gian lọc trong Python. Cách này
    # không cần composite index isActive + nextTriggerDate.
    active_docs = db.collection("recurring_transactions").where("isActive", "==", True).stream()
    due_refs = []
    for doc in active_docs:
        data = doc.to_dict()
        next_trigger = data.get("nextTriggerDate")
        if next_trigger is None:
            continue
        try:
            if _to_datetime(next_trigger) <= now:
                due_refs.append(doc.reference)
        except Exception:
            due_refs.append(doc.reference)

    processed: list[dict] = []
    errors: list[dict] = []

    for recurring_ref in due_refs:
        transaction_ref = db.collection("transactions").document()
        db_transaction = db.transaction()

        try:
            @firestore.transactional
            def apply_recurring(tx):
                recurring_doc = recurring_ref.get(transaction=tx)
                if not recurring_doc.exists:
                    return None

                recurring_data = recurring_doc.to_dict()
                if recurring_data.get("isActive") is not True:
                    return None

                trigger_date = recurring_data.get("nextTriggerDate")
                if trigger_date is None or _to_datetime(trigger_date) > now:
                    return None

                wallet_ref = db.collection("wallets").document(recurring_data.get("walletId", ""))
                category_ref = db.collection("categories").document(recurring_data.get("categoryId", ""))
                wallet_doc = wallet_ref.get(transaction=tx)
                category_doc = category_ref.get(transaction=tx)

                if not wallet_doc.exists:
                    raise RuntimeError("Không tìm thấy ví")
                if not category_doc.exists:
                    raise RuntimeError("Không tìm thấy danh mục")

                wallet_data = wallet_doc.to_dict()
                category_data = category_doc.to_dict()
                user_id = recurring_data.get("userId", "")
                transaction_type = recurring_data.get("type")
                try:
                    _validate_wallet_and_category(
                        wallet_data,
                        category_data,
                        user_id,
                        transaction_type,
                    )
                except HTTPException as exc:
                    raise RuntimeError(str(exc.detail)) from exc

                amount = _money(recurring_data.get("amount", 0))
                current_balance = _money(wallet_data.get("balance", 0))
                balance_delta = amount if transaction_type == "Thu" else -amount
                new_balance = _money(current_balance + balance_delta)
                if new_balance < 0:
                    raise RuntimeError(
                        f"Số dư ví không đủ: hiện có {current_balance:g}, cần {amount:g}"
                    )

                next_date = _next_future_trigger(
                    _to_datetime(trigger_date),
                    recurring_data.get("cycle", "monthly"),
                    now,
                )
                note = recurring_data.get("note", "").strip()
                automatic_note = f"{note} (Tự động - Lặp lại)" if note else "Tự động - Lặp lại"

                transaction_data = {
                    "id": transaction_ref.id,
                    "userId": user_id,
                    "walletId": wallet_ref.id,
                    "walletName": wallet_data.get("name", ""),
                    "categoryId": category_ref.id,
                    "categoryName": category_data.get("name", ""),
                    "categoryIcon": category_data.get("icon", ""),
                    "amount": amount,
                    "type": transaction_type,
                    "date": now,
                    "note": automatic_note,
                    "isFromRecurring": True,
                    "recurringId": recurring_ref.id,
                }

                tx.set(transaction_ref, transaction_data)
                tx.update(wallet_ref, {"balance": new_balance})
                tx.update(
                    recurring_ref,
                    {
                        "walletName": wallet_data.get("name", ""),
                        "categoryName": category_data.get("name", ""),
                        "categoryIcon": category_data.get("icon", ""),
                        "nextTriggerDate": next_date,
                        "lastProcessedAt": now,
                        "lastError": firestore.DELETE_FIELD,
                    },
                )

                return {
                    "recurringId": recurring_ref.id,
                    "transactionId": transaction_ref.id,
                    "amount": amount,
                    "nextTriggerDate": next_date.isoformat(),
                }

            result = apply_recurring(db_transaction)
            if result is not None:
                processed.append(result)
        except Exception as exc:
            reason = str(exc)
            errors.append({"recurringId": recurring_ref.id, "reason": reason})
            try:
                recurring_ref.update({"lastError": reason, "lastErrorAt": now})
            except Exception:
                pass

    return {
        "processedCount": len(processed),
        "processed": processed,
        "errors": errors,
    }


@router.post("/recurring_transactions/")
def create_recurring_transaction(recurring: RecurringTransactionCreate):
    try:
        db = firestore.client()
        wallet_doc = db.collection("wallets").document(recurring.walletId).get()
        category_doc = db.collection("categories").document(recurring.categoryId).get()
        if not wallet_doc.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy ví")
        if not category_doc.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy danh mục")

        user_id = recurring.userId.strip()
        wallet_data = wallet_doc.to_dict()
        category_data = category_doc.to_dict()
        _validate_wallet_and_category(wallet_data, category_data, user_id, recurring.type)

        doc_ref = db.collection("recurring_transactions").document()
        data = _model_dump(recurring)
        data.update(
            {
                "id": doc_ref.id,
                "userId": user_id,
                "walletName": wallet_data.get("name", ""),
                "categoryName": category_data.get("name", ""),
                "categoryIcon": category_data.get("icon", ""),
                "amount": _money(recurring.amount),
                "note": recurring.note.strip(),
                "nextTriggerDate": _normalize_datetime(recurring.nextTriggerDate),
            }
        )
        doc_ref.set(data)
        return {
            "status": "success",
            "message": "Đã thiết lập giao dịch lặp lại",
            "data": data,
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/recurring_transactions/user/{user_id}")
def get_user_recurring_transactions(user_id: str):
    try:
        db = firestore.client()
        items = []
        docs = (
            db.collection("recurring_transactions")
            .where("userId", "==", user_id)
            .stream()
        )
        for doc in docs:
            data = doc.to_dict()
            data.setdefault("id", doc.id)
            items.append(data)
        items.sort(
            key=lambda item: _to_datetime(item.get("nextTriggerDate"))
            if item.get("nextTriggerDate")
            else datetime.max.replace(tzinfo=timezone.utc)
        )
        return {"status": "success", "total": len(items), "data": items}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.put("/recurring_transactions/{recurring_id}")
def update_recurring_transaction(
    recurring_id: str,
    recurring: RecurringTransactionUpdate,
):
    try:
        db = firestore.client()
        doc_ref = db.collection("recurring_transactions").document(recurring_id)
        snapshot = doc_ref.get()
        if not snapshot.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch lặp lại")

        current = snapshot.to_dict()
        changes = _model_dump(recurring, exclude_none=True)
        if not changes:
            return {"status": "success", "message": "Không có gì thay đổi", "data": current}

        user_id = current.get("userId", "")
        wallet_id = changes.get("walletId", current.get("walletId"))
        category_id = changes.get("categoryId", current.get("categoryId"))
        transaction_type = changes.get("type", current.get("type"))

        wallet_doc = db.collection("wallets").document(wallet_id).get()
        category_doc = db.collection("categories").document(category_id).get()
        if not wallet_doc.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy ví")
        if not category_doc.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy danh mục")

        wallet_data = wallet_doc.to_dict()
        category_data = category_doc.to_dict()
        _validate_wallet_and_category(wallet_data, category_data, user_id, transaction_type)

        changes.update(
            {
                "walletId": wallet_id,
                "walletName": wallet_data.get("name", ""),
                "categoryId": category_id,
                "categoryName": category_data.get("name", ""),
                "categoryIcon": category_data.get("icon", ""),
                "type": transaction_type,
            }
        )
        if "amount" in changes:
            changes["amount"] = _money(changes["amount"])
        if "note" in changes:
            changes["note"] = changes["note"].strip()
        if "nextTriggerDate" in changes:
            changes["nextTriggerDate"] = _normalize_datetime(changes["nextTriggerDate"])
        if changes.get("isActive") is True:
            changes["lastError"] = firestore.DELETE_FIELD

        doc_ref.update(changes)
        updated = {**current, **changes}
        updated.pop("lastError", None) if changes.get("lastError") is firestore.DELETE_FIELD else None
        return {
            "status": "success",
            "message": "Đã cập nhật giao dịch lặp lại",
            "data": updated,
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.delete("/recurring_transactions/{recurring_id}")
def delete_recurring_transaction(recurring_id: str):
    try:
        doc_ref = firestore.client().collection("recurring_transactions").document(recurring_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch lặp lại")
        doc_ref.delete()
        return {"status": "success", "message": "Đã xóa giao dịch lặp lại"}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/recurring_transactions/run-now/")
def run_recurring_now():
    try:
        return {"status": "success", **process_recurring_transactions()}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
