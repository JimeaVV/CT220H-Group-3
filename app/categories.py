from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from firebase_admin import firestore

router = APIRouter(tags=["Categories"])

# ==========================================
# --- SCHEMAS CHO DANH MỤC ---
# ==========================================
class CategoryCreate(BaseModel):
    userId: Optional[str] = ""  # Mặc định để rỗng cho các danh mục hệ thống
    name: str
    type: str  # "Thu" hoặc "Chi"
    icon: str

# ==========================================
# --- CÁC API DANH MỤC ---
# ==========================================

# 1. API: Lấy toàn bộ danh mục (Gộp Mặc định + Của riêng User)
@router.get("/categories/{user_id}")
def get_categories(user_id: str):
    try:
        db = firestore.client()
        categories_ref = db.collection('categories')
        
        # Bước 1: Lấy các danh mục mặc định (userId = "")
        default_query = categories_ref.where('userId', '==', '').stream()
        default_categories = [doc.to_dict() for doc in default_query]
        
        # Bước 2: Lấy các danh mục tự tạo của user này
        user_query = categories_ref.where('userId', '==', user_id).stream()
        user_categories = [doc.to_dict() for doc in user_query]
        
        # Bước 3: Gộp 2 danh sách lại trả về cho app
        all_categories = default_categories + user_categories
        
        return {"status": "success", "total": len(all_categories), "data": all_categories}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 2. API: User tự tạo danh mục riêng
@router.post("/categories/")
def create_category(category: CategoryCreate):
    try:
        db = firestore.client()
        doc_ref = db.collection('categories').document()
        data = category.dict()
        data['id'] = doc_ref.id
        doc_ref.set(data)
        return {"status": "success", "message": "Đã tạo danh mục thành công", "data": data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 3. API ADMIN: Khởi tạo dữ liệu danh mục mặc định (Đã thêm chống trùng lặp)
@router.post("/categories/init-defaults/")
def init_default_categories():
    try:
        db = firestore.client()
        categories_ref = db.collection('categories')
        
        # --- BƯỚC MỚI: Kiểm tra xem đã có danh mục hệ thống nào chưa ---
        # limit(1) giúp tìm kiếm nhanh, chỉ cần thấy 1 cái là dừng tìm ngay
        existing_defaults = list(categories_ref.where('userId', '==', '').limit(1).stream())
        
        if len(existing_defaults) > 0:
            # Nếu tìm thấy, báo luôn cho Admin biết và KHÔNG tạo thêm nữa
            return {
                "status": "info", 
                "message": "Hệ thống đã có sẵn danh mục mặc định rồi, không cần tạo lại đâu nhé!"
            }
        # ---------------------------------------------------------------

        # Nếu chưa có thì tiến hành tạo mới
        defaults = [
            {"name": "Ăn uống", "type": "Chi", "icon": "🍜", "userId": ""},
            {"name": "Tiền nhà", "type": "Chi", "icon": "🏠", "userId": ""},
            {"name": "Di chuyển", "type": "Chi", "icon": "🚌", "userId": ""},
            {"name": "Mua sắm", "type": "Chi", "icon": "🛍️", "userId": ""},
            {"name": "Tiền lương", "type": "Thu", "icon": "💰", "userId": ""},
            {"name": "Tiền thưởng", "type": "Thu", "icon": "🎁", "userId": ""}
        ]
        
        batch = db.batch()
        for cat in defaults:
            doc_ref = categories_ref.document()
            cat['id'] = doc_ref.id
            batch.set(doc_ref, cat)
            
        batch.commit()
        return {"status": "success", "message": "Đã tạo xong dữ liệu danh mục mặc định!"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))