from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime, timedelta, timezone
from firebase_admin import firestore

# Múi giờ Việt Nam (UTC+7)
VN_TZ = timezone(timedelta(hours=7))

router = APIRouter(tags=["Budgets"])

# ==========================================
# --- SCHEMAS CHO NGÂN SÁCH ---
# ==========================================

class BudgetCreate(BaseModel):
    userId: str
    categoryId: str
    categoryName: str
    amountLimit: int = Field(gt=0, description="Hạn mức ngân sách phải lớn hơn 0")
    month: int = Field(ge=1, le=12, description="Tháng từ 1 đến 12")
    year: int = Field(ge=2000, description="Năm phải từ 2000 trở đi")

class BudgetUpdate(BaseModel):
    categoryId: Optional[str] = None
    categoryName: Optional[str] = None
    amountLimit: Optional[int] = Field(default=None, gt=0, description="Hạn mức ngân sách phải lớn hơn 0")
    month: Optional[int] = Field(default=None, ge=1, le=12, description="Tháng từ 1 đến 12")
    year: Optional[int] = Field(default=None, ge=2000, description="Năm phải từ 2000 trở đi")

# ==========================================
# --- CÁC API QUẢN LÝ NGÂN SÁCH ---
# ==========================================

# 1. TẠO NGÂN SÁCH
@router.post("/budgets/")
def create_budget(budget: BudgetCreate):
    try:
        db = firestore.client()
        doc_ref = db.collection('budgets').document()
        data = budget.dict()
        data['id'] = doc_ref.id
        doc_ref.set(data)
        return {"status": "success", "message": "Đã tạo Ngân sách", "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 2. LẤY DANH SÁCH NGÂN SÁCH CỦA USER
@router.get("/budgets/user/{user_id}")
def get_user_budgets(user_id: str):
    try:
        db = firestore.client()
        budgets_ref = db.collection('budgets').where('userId', '==', user_id).stream()
        budgets_list = [doc.to_dict() for doc in budgets_ref]
        return {"status": "success", "total": len(budgets_list), "data": budgets_list}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 3. CẬP NHẬT NGÂN SÁCH
@router.put("/budgets/{budget_id}")
def update_budget(budget_id: str, budget: BudgetUpdate):
    try:
        db = firestore.client()
        doc_ref = db.collection('budgets').document(budget_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy ngân sách này")

        update_data = {k: v for k, v in budget.dict().items() if v is not None}
        if update_data:
            doc_ref.update(update_data)

        return {"status": "success", "message": "Đã cập nhật ngân sách", "data": doc_ref.get().to_dict()}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 4. XÓA NGÂN SÁCH
@router.delete("/budgets/{budget_id}")
def delete_budget(budget_id: str):
    try:
        db = firestore.client()
        doc_ref = db.collection('budgets').document(budget_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy ngân sách này")

        doc_ref.delete()
        return {"status": "success", "message": f"Đã xóa ngân sách {budget_id}"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 5. KIỂM TRA TRẠNG THÁI NGÂN SÁCH
@router.get("/budgets/user/{user_id}/status")
def get_budget_status(
    user_id: str,
    month: int = Query(..., description="Tháng cần kiểm tra (1-12)"),
    year: int = Query(..., description="Năm cần kiểm tra")
):
    try:
        db = firestore.client()

        # Bước 1: Lấy tất cả ngân sách của user trong tháng/năm được chọn
        budgets_ref = (
            db.collection('budgets')
            .where('userId', '==', user_id)
            .where('month', '==', month)
            .where('year', '==', year)
            .stream()
        )
        budgets_list = [doc.to_dict() for doc in budgets_ref]

        if not budgets_list:
            return {"status": "success", "message": "User chưa thiết lập ngân sách nào cho tháng này", "data": []}

        # Bước 2: Lấy tất cả giao dịch của user để lọc in-memory (tránh lỗi yêu cầu Composite Index trên Firestore)
        transactions_ref = db.collection('transactions').where('userId', '==', user_id).stream()

        # Bước 3: Gom tổng chi tiêu theo categoryId trong tháng/năm đó
        spending_by_category = {}
        for doc in transactions_ref:
            data = doc.to_dict()
            t_type = data.get('type')
            t_date = data.get('date')
            
            if t_type == "Chi" and t_date:
                # Kiểm tra xem giao dịch có nằm trong tháng và năm yêu cầu không
                if t_date.month == month and t_date.year == year:
                    cat_id = data.get('categoryId', '')
                    spending_by_category[cat_id] = spending_by_category.get(cat_id, 0) + data.get('amount', 0)

        # Bước 4: So sánh hạn mức với thực chi, trả kết quả
        result = []
        for budget in budgets_list:
            cat_id = budget.get('categoryId', '')
            limit = budget.get('amountLimit', 0)
            spent = spending_by_category.get(cat_id, 0)
            remaining = limit - spent

            result.append({
                "budgetId": budget.get('id'),
                "categoryId": cat_id,
                "categoryName": budget.get('categoryName', ''),
                "amountLimit": limit,
                "totalSpent": spent,
                "remaining": remaining,
                "percentUsed": round((spent / limit) * 100, 1) if limit > 0 else 0,
                "isExceeded": spent > limit,
                "isWarning": spent >= limit * 0.8
            })

        return {"status": "success", "month": month, "year": year, "data": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
