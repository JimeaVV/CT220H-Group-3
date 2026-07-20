from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, HTTPException, Query
from firebase_admin import firestore
from pydantic import BaseModel, Field

VN_TZ = timezone(timedelta(hours=7))
router = APIRouter(tags=["Budgets"])


class BudgetCreate(BaseModel):
    userId: str = Field(min_length=1)
    categoryId: str = Field(min_length=1)
    categoryName: str = ""
    amountLimit: float = Field(gt=0)
    month: int = Field(ge=1, le=12)
    year: int = Field(ge=2000, le=2200)


class BudgetUpdate(BaseModel):
    categoryId: Optional[str] = Field(default=None, min_length=1)
    categoryName: Optional[str] = None
    amountLimit: Optional[float] = Field(default=None, gt=0)
    month: Optional[int] = Field(default=None, ge=1, le=12)
    year: Optional[int] = Field(default=None, ge=2000, le=2200)


def _model_dump(model: BaseModel, *, exclude_none: bool = False) -> dict:
    if hasattr(model, "model_dump"):
        return model.model_dump(exclude_none=exclude_none)
    return model.dict(exclude_none=exclude_none)


def _to_vietnam_time(value) -> datetime | None:
    if not isinstance(value, datetime):
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(VN_TZ)


def _validate_expense_category(db, category_id: str, user_id: str) -> dict:
    snapshot = db.collection("categories").document(category_id).get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Không tìm thấy danh mục")

    data = snapshot.to_dict()
    if data.get("userId", "") not in ("", user_id):
        raise HTTPException(status_code=403, detail="Danh mục không thuộc người dùng hiện tại")
    if data.get("type") != "Chi":
        raise HTTPException(status_code=400, detail="Chỉ có thể đặt ngân sách cho danh mục Chi")
    return data


def _find_duplicate_budget(
    db,
    user_id: str,
    category_id: str,
    month: int,
    year: int,
    *,
    exclude_id: str | None = None,
) -> bool:
    docs = db.collection("budgets").where("userId", "==", user_id).stream()
    for doc in docs:
        if exclude_id and doc.id == exclude_id:
            continue
        data = doc.to_dict()
        if (
            data.get("categoryId") == category_id
            and data.get("month") == month
            and data.get("year") == year
        ):
            return True
    return False


@router.post("/budgets/")
def create_budget(budget: BudgetCreate):
    try:
        db = firestore.client()
        user_id = budget.userId.strip()
        category_data = _validate_expense_category(db, budget.categoryId, user_id)

        if _find_duplicate_budget(
            db,
            user_id,
            budget.categoryId,
            budget.month,
            budget.year,
        ):
            raise HTTPException(
                status_code=409,
                detail="Danh mục này đã có ngân sách trong tháng được chọn",
            )

        doc_ref = db.collection("budgets").document()
        data = _model_dump(budget)
        data.update(
            {
                "id": doc_ref.id,
                "userId": user_id,
                "categoryName": category_data.get("name", ""),
                "amountLimit": round(float(budget.amountLimit), 2),
            }
        )
        doc_ref.set(data)
        return {"status": "success", "message": "Đã tạo ngân sách", "data": data}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/budgets/user/{user_id}")
def get_user_budgets(user_id: str):
    try:
        db = firestore.client()
        items = []
        for doc in db.collection("budgets").where("userId", "==", user_id).stream():
            data = doc.to_dict()
            data.setdefault("id", doc.id)
            items.append(data)
        items.sort(key=lambda item: (item.get("year", 0), item.get("month", 0), item.get("categoryName", "")))
        return {"status": "success", "total": len(items), "data": items}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.put("/budgets/{budget_id}")
def update_budget(budget_id: str, budget: BudgetUpdate):
    try:
        db = firestore.client()
        doc_ref = db.collection("budgets").document(budget_id)
        snapshot = doc_ref.get()
        if not snapshot.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy ngân sách")

        current = snapshot.to_dict()
        changes = _model_dump(budget, exclude_none=True)
        if not changes:
            return {"status": "success", "message": "Không có gì thay đổi", "data": current}

        user_id = current.get("userId", "")
        category_id = changes.get("categoryId", current.get("categoryId"))
        month = changes.get("month", current.get("month"))
        year = changes.get("year", current.get("year"))
        category_data = _validate_expense_category(db, category_id, user_id)

        if _find_duplicate_budget(
            db,
            user_id,
            category_id,
            month,
            year,
            exclude_id=budget_id,
        ):
            raise HTTPException(
                status_code=409,
                detail="Danh mục này đã có ngân sách trong tháng được chọn",
            )

        changes.update(
            {
                "categoryId": category_id,
                "categoryName": category_data.get("name", ""),
                "month": month,
                "year": year,
            }
        )
        if "amountLimit" in changes:
            changes["amountLimit"] = round(float(changes["amountLimit"]), 2)

        doc_ref.update(changes)
        updated = {**current, **changes}
        return {"status": "success", "message": "Đã cập nhật ngân sách", "data": updated}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.delete("/budgets/{budget_id}")
def delete_budget(budget_id: str):
    try:
        doc_ref = firestore.client().collection("budgets").document(budget_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy ngân sách")
        doc_ref.delete()
        return {"status": "success", "message": "Đã xóa ngân sách"}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/budgets/user/{user_id}/status")
def get_budget_status(
    user_id: str,
    month: int = Query(..., ge=1, le=12),
    year: int = Query(..., ge=2000, le=2200),
):
    try:
        db = firestore.client()
        all_budgets = []
        for doc in db.collection("budgets").where("userId", "==", user_id).stream():
            data = doc.to_dict()
            data.setdefault("id", doc.id)
            all_budgets.append(data)
        budgets = [
            item
            for item in all_budgets
            if item.get("month") == month and item.get("year") == year
        ]

        if not budgets:
            return {
                "status": "success",
                "message": "Chưa có ngân sách trong tháng này",
                "data": [],
            }

        spending_by_category: dict[str, float] = {}
        transaction_docs = db.collection("transactions").where("userId", "==", user_id).stream()
        for doc in transaction_docs:
            data = doc.to_dict()
            if data.get("type") != "Chi":
                continue
            transaction_date = _to_vietnam_time(data.get("date"))
            if transaction_date is None:
                continue
            if transaction_date.month != month or transaction_date.year != year:
                continue

            category_id = data.get("categoryId", "")
            spending_by_category[category_id] = (
                spending_by_category.get(category_id, 0.0) + float(data.get("amount", 0))
            )

        result = []
        for budget in budgets:
            category_id = budget.get("categoryId", "")
            limit = float(budget.get("amountLimit", 0))
            spent = round(spending_by_category.get(category_id, 0.0), 2)
            remaining = round(limit - spent, 2)
            percent = round((spent / limit) * 100, 1) if limit > 0 else 0.0
            exceeded = spent > limit

            result.append(
                {
                    "budgetId": budget.get("id", ""),
                    "categoryId": category_id,
                    "categoryName": budget.get("categoryName", ""),
                    "amountLimit": round(limit, 2),
                    "totalSpent": spent,
                    "remaining": remaining,
                    "percentUsed": percent,
                    "isExceeded": exceeded,
                    "isWarning": (not exceeded) and spent >= limit * 0.8,
                }
            )

        result.sort(key=lambda item: item["percentUsed"], reverse=True)
        return {"status": "success", "month": month, "year": year, "data": result}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
