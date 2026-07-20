from __future__ import annotations

from typing import Literal, Optional

from fastapi import APIRouter, HTTPException
from firebase_admin import firestore
from pydantic import BaseModel, Field

router = APIRouter(tags=["Categories"])


class CategoryCreate(BaseModel):
    userId: str = ""
    name: str = Field(min_length=1, max_length=80)
    type: Literal["Thu", "Chi"]
    icon: str = Field(default="", max_length=20)


class CategoryUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=80)
    type: Optional[Literal["Thu", "Chi"]] = None
    icon: Optional[str] = Field(default=None, max_length=20)


def _model_dump(model: BaseModel, *, exclude_none: bool = False) -> dict:
    if hasattr(model, "model_dump"):
        return model.model_dump(exclude_none=exclude_none)
    return model.dict(exclude_none=exclude_none)


def _normalized_name(value: str) -> str:
    return " ".join(value.strip().split())


def _category_is_referenced(db, category_id: str) -> bool:
    checks = (
        ("transactions", "categoryId"),
        ("budgets", "categoryId"),
        ("recurring_transactions", "categoryId"),
    )
    for collection_name, field_name in checks:
        found = list(
            db.collection(collection_name)
            .where(field_name, "==", category_id)
            .limit(1)
            .stream()
        )
        if found:
            return True
    return False


def _sync_denormalized_category_fields(db, category_id: str, name: str, icon: str) -> None:
    collections = ("transactions", "recurring_transactions")
    batch = db.batch()
    operations = 0

    for collection_name in collections:
        docs = db.collection(collection_name).where("categoryId", "==", category_id).stream()
        for doc in docs:
            batch.update(doc.reference, {"categoryName": name, "categoryIcon": icon})
            operations += 1
            if operations >= 450:
                batch.commit()
                batch = db.batch()
                operations = 0

    budget_docs = db.collection("budgets").where("categoryId", "==", category_id).stream()
    for doc in budget_docs:
        batch.update(doc.reference, {"categoryName": name})
        operations += 1
        if operations >= 450:
            batch.commit()
            batch = db.batch()
            operations = 0

    if operations:
        batch.commit()


@router.get("/categories/{user_id}")
def get_categories(user_id: str):
    try:
        db = firestore.client()
        categories_ref = db.collection("categories")

        defaults = []
        for doc in categories_ref.where("userId", "==", "").stream():
            data = doc.to_dict()
            data.setdefault("id", doc.id)
            defaults.append(data)

        personal = []
        for doc in categories_ref.where("userId", "==", user_id).stream():
            data = doc.to_dict()
            data.setdefault("id", doc.id)
            personal.append(data)

        categories = defaults + personal
        categories.sort(key=lambda item: (item.get("type", ""), item.get("name", "").casefold()))
        return {"status": "success", "total": len(categories), "data": categories}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/categories/")
def create_category(category: CategoryCreate):
    try:
        db = firestore.client()
        name = _normalized_name(category.name)
        if not name:
            raise HTTPException(status_code=422, detail="Tên danh mục không được để trống")

        owner_id = category.userId.strip()
        existing_docs = db.collection("categories").where("userId", "==", owner_id).stream()
        duplicate = any(
            (doc.to_dict().get("name", "").strip().casefold() == name.casefold())
            and doc.to_dict().get("type") == category.type
            for doc in existing_docs
        )
        if duplicate:
            raise HTTPException(status_code=409, detail="Danh mục này đã tồn tại")

        doc_ref = db.collection("categories").document()
        data = _model_dump(category)
        data.update(
            {
                "id": doc_ref.id,
                "userId": owner_id,
                "name": name,
                "icon": category.icon.strip(),
            }
        )
        doc_ref.set(data)
        return {"status": "success", "message": "Đã tạo danh mục", "data": data}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.put("/categories/{category_id}")
def update_category(category_id: str, category: CategoryUpdate):
    try:
        db = firestore.client()
        doc_ref = db.collection("categories").document(category_id)
        snapshot = doc_ref.get()
        if not snapshot.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy danh mục")

        current = snapshot.to_dict()
        if not current.get("userId"):
            raise HTTPException(status_code=403, detail="Không thể sửa danh mục mặc định")

        update_data = _model_dump(category, exclude_none=True)
        if not update_data:
            return {"status": "success", "message": "Không có gì thay đổi", "data": current}

        if "name" in update_data:
            update_data["name"] = _normalized_name(update_data["name"])
            if not update_data["name"]:
                raise HTTPException(status_code=422, detail="Tên danh mục không được để trống")
        if "icon" in update_data:
            update_data["icon"] = update_data["icon"].strip()

        new_name = update_data.get("name", current.get("name", ""))
        new_type = update_data.get("type", current.get("type", "Chi"))
        owner_id = current.get("userId", "")

        duplicate_docs = db.collection("categories").where("userId", "==", owner_id).stream()
        for other in duplicate_docs:
            if other.id == category_id:
                continue
            other_data = other.to_dict()
            if (
                other_data.get("name", "").strip().casefold() == new_name.casefold()
                and other_data.get("type") == new_type
            ):
                raise HTTPException(status_code=409, detail="Danh mục này đã tồn tại")

        if new_type == "Thu":
            has_budget = list(
                db.collection("budgets")
                .where("categoryId", "==", category_id)
                .limit(1)
                .stream()
            )
            if has_budget:
                raise HTTPException(
                    status_code=409,
                    detail="Danh mục đang có ngân sách nên không thể đổi thành loại Thu",
                )

        doc_ref.update(update_data)
        updated = doc_ref.get().to_dict()
        _sync_denormalized_category_fields(
            db,
            category_id,
            updated.get("name", ""),
            updated.get("icon", ""),
        )
        return {"status": "success", "message": "Đã cập nhật danh mục", "data": updated}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.delete("/categories/{category_id}")
def delete_category(category_id: str):
    try:
        db = firestore.client()
        doc_ref = db.collection("categories").document(category_id)
        snapshot = doc_ref.get()
        if not snapshot.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy danh mục")
        if not snapshot.to_dict().get("userId"):
            raise HTTPException(status_code=403, detail="Không thể xóa danh mục mặc định")
        if _category_is_referenced(db, category_id):
            raise HTTPException(
                status_code=409,
                detail="Danh mục đang được sử dụng bởi giao dịch, ngân sách hoặc giao dịch lặp",
            )

        doc_ref.delete()
        return {"status": "success", "message": "Đã xóa danh mục"}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.post("/categories/init-defaults/")
def init_default_categories():
    try:
        db = firestore.client()
        categories_ref = db.collection("categories")
        defaults = [
            {"name": "Ăn uống", "type": "Chi", "icon": "🍜", "userId": ""},
            {"name": "Tiền nhà", "type": "Chi", "icon": "🏠", "userId": ""},
            {"name": "Di chuyển", "type": "Chi", "icon": "🚌", "userId": ""},
            {"name": "Mua sắm", "type": "Chi", "icon": "🛍️", "userId": ""},
            {"name": "Hóa đơn", "type": "Chi", "icon": "🧾", "userId": ""},
            {"name": "Giải trí", "type": "Chi", "icon": "🎮", "userId": ""},
            {"name": "Sức khỏe", "type": "Chi", "icon": "💊", "userId": ""},
            {"name": "Giáo dục", "type": "Chi", "icon": "📚", "userId": ""},
            {"name": "Tiền lương", "type": "Thu", "icon": "💰", "userId": ""},
            {"name": "Tiền thưởng", "type": "Thu", "icon": "🎁", "userId": ""},
            {"name": "Trợ cấp", "type": "Thu", "icon": "🤝", "userId": ""},
            {"name": "Thu nhập khác", "type": "Thu", "icon": "➕", "userId": ""},
        ]

        existing = [
            doc.to_dict()
            for doc in categories_ref.where("userId", "==", "").stream()
        ]
        existing_keys = {
            (item.get("name", "").strip().casefold(), item.get("type"))
            for item in existing
        }

        batch = db.batch()
        created = 0
        for item in defaults:
            key = (item["name"].casefold(), item["type"])
            if key in existing_keys:
                continue
            doc_ref = categories_ref.document()
            data = {**item, "id": doc_ref.id}
            batch.set(doc_ref, data)
            created += 1

        if created:
            batch.commit()

        return {
            "status": "success",
            "message": f"Đã bổ sung {created} danh mục mặc định",
            "createdCount": created,
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
