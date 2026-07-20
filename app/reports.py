from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, HTTPException, Query
from firebase_admin import firestore

router = APIRouter(tags=["Reports"])
VN_TZ = timezone(timedelta(hours=7))


def _to_vietnam_time(value) -> datetime | None:
    if not isinstance(value, datetime):
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(VN_TZ)


def _user_transactions(db, user_id: str) -> list[dict]:
    return [
        doc.to_dict()
        for doc in db.collection("transactions").where("userId", "==", user_id).stream()
    ]


@router.get("/reports/summary/{user_id}")
def get_report_summary(user_id: str):
    try:
        db = firestore.client()
        wallets = db.collection("wallets").where("userId", "==", user_id).stream()
        current_balance = sum(float(doc.to_dict().get("balance", 0)) for doc in wallets)

        now = datetime.now(VN_TZ)
        total_income = 0.0
        total_expense = 0.0

        # Chỉ dùng query userId rồi lọc thời gian trong Python để không bắt người dùng
        # phải tạo composite index userId + date.
        for data in _user_transactions(db, user_id):
            transaction_date = _to_vietnam_time(data.get("date"))
            if transaction_date is None:
                continue
            if transaction_date.year != now.year or transaction_date.month != now.month:
                continue

            amount = float(data.get("amount", 0))
            if data.get("type") == "Thu":
                total_income += amount
            elif data.get("type") == "Chi":
                total_expense += amount

        return {
            "status": "success",
            "data": {
                "currentBalance": round(current_balance, 2),
                "totalIncome": round(total_income, 2),
                "totalExpense": round(total_expense, 2),
                "month": now.month,
                "year": now.year,
            },
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get("/reports/chart/{user_id}")
def get_chart_data(
    user_id: str,
    period: Literal["week", "month"] = Query(
        "month",
        description="week: 7 ngày gần nhất, month: 30 ngày gần nhất",
    ),
):
    try:
        db = firestore.client()
        now = datetime.now(VN_TZ)
        day_count = 7 if period == "week" else 30
        start_day = (now - timedelta(days=day_count - 1)).date()

        daily_data: dict[str, dict[str, float]] = {}
        for data in _user_transactions(db, user_id):
            transaction_date = _to_vietnam_time(data.get("date"))
            if transaction_date is None:
                continue
            if transaction_date.date() < start_day or transaction_date > now:
                continue

            transaction_type = data.get("type")
            if transaction_type not in ("Thu", "Chi"):
                continue

            date_key = transaction_date.strftime("%Y-%m-%d")
            daily_data.setdefault(date_key, {"Thu": 0.0, "Chi": 0.0})
            daily_data[date_key][transaction_type] += float(data.get("amount", 0))

        chart_list = [
            {
                "date": date_key,
                "income": round(values["Thu"], 2),
                "expense": round(values["Chi"], 2),
            }
            for date_key, values in sorted(daily_data.items())
        ]

        return {"status": "success", "period": period, "data": chart_list}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
