from fastapi import APIRouter, HTTPException, Query
from datetime import datetime, timedelta
from firebase_admin import firestore

router = APIRouter(tags=["Reports"])

# 1. API: TỔNG QUAN (Số dư hiện tại, Tổng thu, Tổng chi trong tháng)
@router.get("/reports/summary/{user_id}")
def get_report_summary(user_id: str):
    try:
        db = firestore.client()
        
        # 1. Tính tổng Số dư hiện tại từ tất cả các Ví (Wallets)
        wallets_ref = db.collection('wallets').where('userId', '==', user_id).stream()
        current_balance = sum([doc.to_dict().get('balance', 0) for doc in wallets_ref])
        
        # 2. Lấy giao dịch trong tháng hiện tại để tính Tổng Thu / Chi
        now = datetime.now()
        current_month = now.month
        current_year = now.year
        
        transactions_ref = db.collection('transactions').where('userId', '==', user_id).stream()
        
        total_income = 0
        total_expense = 0
        
        for doc in transactions_ref:
            data = doc.to_dict()
            # Firestore lưu date dưới dạng Datetime có timezone (UTC)
            t_date = data.get('date') 
            if t_date:
                # Kiểm tra xem giao dịch có nằm trong tháng và năm hiện tại không
                if t_date.month == current_month and t_date.year == current_year:
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
        now = datetime.now()
        
        # Xác định khoảng thời gian cần thống kê
        days_to_subtract = 7 if period == 'week' else 30
        start_date = now - timedelta(days=days_to_subtract)
        
        transactions_ref = db.collection('transactions').where('userId', '==', user_id).stream()
        
        # Tạo một dictionary để gom nhóm dữ liệu theo ngày. Ví dụ: {'2026-07-06': {'Thu': 100, 'Chi': 50}}
        daily_data = {}
        
        for doc in transactions_ref:
            data = doc.to_dict()
            t_date = data.get('date')
            
            if t_date:
                # Đưa timezone về dạng naive (nếu có) để dễ so sánh, hoặc bỏ qua múi giờ
                t_date_naive = t_date.replace(tzinfo=None) 
                
                # Chỉ lấy những giao dịch nằm trong khoảng thời gian đã chọn
                if start_date <= t_date_naive <= now:
                    # Lấy chuỗi ngày (VD: '2026-07-06') làm chìa khóa gom nhóm
                    date_str = t_date_naive.strftime('%Y-%m-%d')
                    
                    if date_str not in daily_data:
                        daily_data[date_str] = {"Thu": 0, "Chi": 0}
                        
                    t_type = data.get('type')
                    t_amount = data.get('amount', 0)
                    
                    if t_type in ["Thu", "Chi"]:
                        daily_data[date_str][t_type] += t_amount
        
        # Biến đổi dictionary thành dạng danh sách (list) để Flutter dễ vẽ biểu đồ hơn
        chart_list = []
        for date_key, values in sorted(daily_data.items()): # Sắp xếp ngày từ cũ đến mới
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