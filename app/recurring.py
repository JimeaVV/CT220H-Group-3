from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime, timedelta, timezone
from firebase_admin import firestore
import calendar
from google.cloud.firestore_v1.base_query import FieldFilter

# Múi giờ Việt Nam (UTC+7)
VN_TZ = timezone(timedelta(hours=7))

router = APIRouter(tags=["Recurring Transactions"])

# ==========================================
# --- SCHEMAS CHO GIAO DỊCH LẶP LẠI ---
# ==========================================

class RecurringTransactionCreate(BaseModel):
    userId: str
    walletId: str
    walletName: str
    categoryId: str
    categoryName: str
    categoryIcon: str
    amount: int = Field(gt=0, description="Số tiền phải lớn hơn 0")
    type: str = Field(description="'Thu' hoặc 'Chi'")
    note: str
    cycle: str = Field(description="'daily' | 'weekly' | 'monthly' | 'yearly'")
    nextTriggerDate: datetime
    isActive: bool = True


class RecurringTransactionUpdate(BaseModel):
    walletId: Optional[str] = None
    walletName: Optional[str] = None
    categoryId: Optional[str] = None
    categoryName: Optional[str] = None
    categoryIcon: Optional[str] = None
    amount: Optional[int] = Field(default=None, gt=0)
    type: Optional[str] = None
    note: Optional[str] = None
    cycle: Optional[str] = None
    nextTriggerDate: Optional[datetime] = None
    isActive: Optional[bool] = None


# ==========================================
# --- HÀM TIỆN ÍCH: TÍNH NGÀY KÍCH HOẠT TIẾP THEO ---
# ==========================================

def calculate_next_trigger_date(current_date: datetime, cycle: str) -> datetime:
    """
    Tính ngày kích hoạt kế tiếp dựa trên chu kỳ.
    Hỗ trợ: daily, weekly, monthly, yearly
    """
    # Firestore trả về kiểu DatetimeWithNanoseconds (không phải datetime chuẩn),
    # khiến .replace(year=..., month=..., day=...) bị lỗi nội bộ.
    # Convert về datetime chuẩn của Python trước khi xử lý để tránh lỗi này.
    if type(current_date) is not datetime:
        current_date = datetime.fromisoformat(current_date.isoformat())

    if cycle == "daily":
        return current_date + timedelta(days=1)

    elif cycle == "weekly":
        return current_date + timedelta(weeks=1)

    elif cycle == "monthly":
        # Cộng thêm 1 tháng, xử lý an toàn cho trường hợp ngày cuối tháng
        # (vd 31/1 -> 28/2 hoặc 29/2 nếu năm nhuận)
        month = current_date.month + 1
        year = current_date.year
        if month > 12:
            month = 1
            year += 1
        last_day_of_month = calendar.monthrange(year, month)[1]
        day = min(current_date.day, last_day_of_month)
        return current_date.replace(year=year, month=month, day=day)

    elif cycle == "yearly":
        try:
            return current_date.replace(year=current_date.year + 1)
        except ValueError:
            # Trường hợp 29/2 năm nhuận -> năm sau không nhuận
            return current_date.replace(year=current_date.year + 1, day=28, month=2)

    else:
        raise ValueError(f"Chu kỳ không hợp lệ: {cycle}")


# ==========================================
# --- LÕI XỬ LÝ: TỰ ĐỘNG GHI NHẬN GIAO DỊCH ĐẾN HẠN ---
# ==========================================

def process_recurring_transactions():
    """
    Quét toàn bộ recurring_transactions đang active và đã đến hạn
    (nextTriggerDate <= thời điểm hiện tại), với mỗi cái:
      1. Tạo 1 giao dịch (transaction) thật trong collection 'transactions'
      2. Cập nhật số dư ví tương ứng
      3. Dời nextTriggerDate sang kỳ tiếp theo

    Hàm này được gọi bởi:
      - API POST /recurring_transactions/run-now/ (chạy tay để test)
      - Scheduler tự động (APScheduler / Cloud Scheduler) chạy định kỳ mỗi ngày
    """
    db = firestore.client()
    now = datetime.now(VN_TZ)

    due_recurrings = (
        db.collection('recurring_transactions')
        .where('isActive', '==', True)
        # Cú pháp mới (Chuẩn Google)
        .where(filter=FieldFilter('nextTriggerDate', '<=', now))
        .stream()
    )

    processed = []
    errors = []

    for doc in due_recurrings:
        rec_data = doc.to_dict()
        rec_id = doc.id

        try:
            wallet_ref = db.collection('wallets').document(rec_data['walletId'])
            wallet_doc = wallet_ref.get()

            if not wallet_doc.exists:
                errors.append({"recurringId": rec_id, "reason": "Không tìm thấy ví"})
                continue

            wallet_data = wallet_doc.to_dict()
            current_balance = wallet_data.get('balance', 0)

            if rec_data['type'] == "Chi":
                new_balance = current_balance - rec_data['amount']
            elif rec_data['type'] == "Thu":
                new_balance = current_balance + rec_data['amount']
            else:
                new_balance = current_balance

            # Tạo giao dịch mới từ cấu hình recurring
            transaction_ref = db.collection('transactions').document()
            transaction_data = {
                "id": transaction_ref.id,
                "userId": rec_data['userId'],
                "walletId": rec_data['walletId'],
                "walletName": rec_data.get('walletName', ''),
                "categoryId": rec_data['categoryId'],
                "categoryName": rec_data.get('categoryName', ''),
                "categoryIcon": rec_data.get('categoryIcon', ''),
                "amount": rec_data['amount'],
                "type": rec_data['type'],
                "date": now,
                "note": rec_data.get('note', '') + " (Tự động - Lặp lại)",
                "isFromRecurring": True,
                "recurringId": rec_id,
            }

            # Tính ngày kích hoạt kế tiếp
            next_date = calculate_next_trigger_date(
                rec_data['nextTriggerDate'], rec_data['cycle']
            )

            # Ghi đồng thời: tạo transaction, cập nhật ví, dời lịch recurring
            batch = db.batch()
            batch.set(transaction_ref, transaction_data)
            batch.update(wallet_ref, {'balance': new_balance})
            batch.update(doc.reference, {'nextTriggerDate': next_date})
            batch.commit()

            processed.append({
                "recurringId": rec_id,
                "transactionId": transaction_ref.id,
                "amount": rec_data['amount'],
                "nextTriggerDate": next_date.isoformat(),
            })

        except Exception as e:
            errors.append({"recurringId": rec_id, "reason": str(e)})

    return {"processedCount": len(processed), "processed": processed, "errors": errors}


# ==========================================
# --- CÁC API QUẢN LÝ RECURRING TRANSACTIONS ---
# ==========================================

# 1. TẠO GIAO DỊCH LẶP LẠI
@router.post("/recurring_transactions/")
def create_recurring_transaction(recurring: RecurringTransactionCreate):
    try:
        db = firestore.client()
        doc_ref = db.collection('recurring_transactions').document()
        data = recurring.dict()
        data['id'] = doc_ref.id
        doc_ref.set(data)
        return {"status": "success", "message": "Đã thiết lập Giao dịch lặp lại", "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# 2. LẤY DANH SÁCH GIAO DỊCH LẶP LẠI CỦA USER
@router.get("/recurring_transactions/user/{user_id}")
def get_user_recurring_transactions(user_id: str):
    try:
        db = firestore.client()
        recurring_ref = (
            db.collection('recurring_transactions')
            .where('userId', '==', user_id)
            .stream()
        )
        recurring_list = [doc.to_dict() for doc in recurring_ref]
        return {"status": "success", "total": len(recurring_list), "data": recurring_list}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# 3. SỬA GIAO DỊCH LẶP LẠI (vd đổi số tiền, tạm dừng bằng isActive=False)
@router.put("/recurring_transactions/{recurring_id}")
def update_recurring_transaction(recurring_id: str, recurring: RecurringTransactionUpdate):
    try:
        db = firestore.client()
        doc_ref = db.collection('recurring_transactions').document(recurring_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch lặp lại này")

        update_data = {k: v for k, v in recurring.dict().items() if v is not None}
        if update_data:
            doc_ref.update(update_data)

        return {
            "status": "success",
            "message": "Đã cập nhật giao dịch lặp lại",
            "data": doc_ref.get().to_dict(),
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# 4. XÓA GIAO DỊCH LẶP LẠI
@router.delete("/recurring_transactions/{recurring_id}")
def delete_recurring_transaction(recurring_id: str):
    try:
        db = firestore.client()
        doc_ref = db.collection('recurring_transactions').document(recurring_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy giao dịch lặp lại này")

        doc_ref.delete()
        return {"status": "success", "message": f"Đã xóa giao dịch lặp lại {recurring_id}"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# 5. CHẠY XỬ LÝ THỦ CÔNG (dùng để TEST trước khi gắn scheduler tự động)
@router.post("/recurring_transactions/run-now/")
def run_recurring_now():
    """
    Gọi API này bằng tay (qua Swagger /docs) để kiểm tra logic xử lý
    recurring transactions mà không cần đợi scheduler chạy tự động.
    """
    try:
        result = process_recurring_transactions()
        return {"status": "success", **result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))