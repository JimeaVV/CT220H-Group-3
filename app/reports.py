from fastapi import APIRouter, HTTPException, Query
from datetime import datetime, timedelta, timezone
from firebase_admin import firestore

router = APIRouter(tags=["Reports"])

# Múi giờ Việt Nam (UTC+7)
VN_TZ = timezone(timedelta(hours=7))

# 1. API: TỔNG QUAN (Số dư hiện tại, Tổng thu, Tổng chi trong tháng)
@router.get("/reports/summary/{user_id}")
def get_report_summary(user_id: str):
    try:
        db = firestore.client()
        
        # 1. Tính tổng Số dư hiện tại từ tất cả các Ví (Wallets)
        wallets_ref = db.collection('wallets').where('userId', '==', user_id).stream()
        current_balance = sum([doc.to_dict().get('balance', 0) for doc in wallets_ref])
        
        # 2. Lấy giao dịch trong tháng hiện tại (theo giờ Việt Nam)
        now = datetime.now(VN_TZ)
        current_month = now.month
        current_year = now.year
        
        # Tính ngày đầu và cuối tháng (timezone-aware)
        start_of_month = datetime(current_year, current_month, 1, tzinfo=VN_TZ)
        if current_month == 12:
            end_of_month = datetime(current_year + 1, 1, 1, tzinfo=VN_TZ)
        else:
            end_of_month = datetime(current_year, current_month + 1, 1, tzinfo=VN_TZ)
        
        # Truy vấn Firestore trực tiếp theo khoảng thời gian thay vì tải toàn bộ
        # LƯU Ý: Cần tạo Composite Index (userId + date) trên Firestore Console
        transactions_ref = (
            db.collection('transactions')
            .where('userId', '==', user_id)
            .where('date', '>=', start_of_month)
            .where('date', '<', end_of_month)
            .stream()
        )
        
        total_income = 0
        total_expense = 0
        
        for doc in transactions_ref:
            data = doc.to_dict()
            if data.get('type') == 'Thu':
                total_income += data.get('amount', 0)
            elif data.get('type') == 'Chi':
                total_expense += data.get('amount', 0)
                    
        return {
            "status": "success",
            "data": {
                "currentBalance": current_balance,
                "totalIncome": total_income,
                "totalExpense": total_expense,
                "month": current_month,
                "year": current_year
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 2. API: DỮ LIỆU BIỂU ĐỒ (Gom nhóm thu/chi theo từng ngày)
@router.get("/reports/chart/{user_id}")
def get_chart_data(
    user_id: str, 
    period: str = Query("month", description="Chọn 'week' (7 ngày qua) hoặc 'month' (30 ngày qua)")
):
    try:
        db = firestore.client()
        now = datetime.now(VN_TZ)
        
        # Xác định khoảng thời gian cần thống kê
        days_to_subtract = 7 if period == 'week' else 30
        start_date = now - timedelta(days=days_to_subtract)
        
        # Truy vấn Firestore trực tiếp theo khoảng thời gian thay vì tải toàn bộ
        # LƯU Ý: Cần tạo Composite Index (userId + date) trên Firestore Console
        transactions_ref = (
            db.collection('transactions')
            .where('userId', '==', user_id)
            .where('date', '>=', start_date)
            .where('date', '<=', now)
            .stream()
        )
        
        # Tạo dictionary để gom nhóm dữ liệu theo ngày
        daily_data = {}
        
        for doc in transactions_ref:
            data = doc.to_dict()
            t_date = data.get('date')
            
            if t_date:
                # Chuyển về giờ Việt Nam trước khi nhóm theo ngày
                t_date_vn = t_date.astimezone(VN_TZ)
                date_str = t_date_vn.strftime('%Y-%m-%d')
                
                if date_str not in daily_data:
                    daily_data[date_str] = {"Thu": 0, "Chi": 0}
                    
                t_type = data.get('type')
                t_amount = data.get('amount', 0)
                
                if t_type in ["Thu", "Chi"]:
                    daily_data[date_str][t_type] += t_amount
        
        # Biến đổi dictionary thành danh sách để Flutter dễ vẽ biểu đồ
        chart_list = []
        for date_key, values in sorted(daily_data.items()):
            chart_list.append({
                "date": date_key,
                "income": values["Thu"],
                "expense": values["Chi"]
            })
            
        return {
            "status": "success",
            "period": period,
            "data": chart_list
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))