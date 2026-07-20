from __future__ import annotations

import asyncio
import logging
import os
from contextlib import asynccontextmanager, suppress
from pathlib import Path

import firebase_admin
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from firebase_admin import credentials, firestore
from pydantic import BaseModel, Field

from app.budgets import router as budget_router
from app.categories import router as category_router
from app.recurring import process_recurring_transactions
from app.recurring import router as recurring_router
from app.reports import router as report_router
from app.transactions import router as transaction_router
from app.wallets import router as wallet_router

logger = logging.getLogger("fintrack")


def _model_dump(model: BaseModel) -> dict:
    if hasattr(model, "model_dump"):
        return model.model_dump()
    return model.dict()


def _initialize_firebase() -> None:
    """Khởi tạo Firebase Admin một lần, không phụ thuộc thư mục chạy Uvicorn."""
    if firebase_admin._apps:
        return

    configured_path = os.getenv("FIREBASE_SERVICE_ACCOUNT", "").strip()
    default_path = Path(__file__).resolve().parent.parent / "serviceAccountKey.json"
    credential_path = Path(configured_path).expanduser() if configured_path else default_path

    if credential_path.is_file():
        firebase_admin.initialize_app(credentials.Certificate(str(credential_path)))
        return

    # Hỗ trợ Application Default Credentials khi deploy lên Google Cloud.
    try:
        firebase_admin.initialize_app()
    except Exception as exc:
        raise RuntimeError(
            "Không tìm thấy Firebase credential. Hãy đặt serviceAccountKey.json ở thư mục "
            "gốc dự án hoặc khai báo biến FIREBASE_SERVICE_ACCOUNT."
        ) from exc


_initialize_firebase()
db = firestore.client()


async def _recurring_worker() -> None:
    """Chạy giao dịch lặp định kỳ khi backend đang hoạt động."""
    raw_interval = os.getenv("RECURRING_INTERVAL_SECONDS", "3600")
    try:
        interval = max(60, int(raw_interval))
    except ValueError:
        interval = 3600

    while True:
        try:
            result = await asyncio.to_thread(process_recurring_transactions)
            if result.get("processedCount", 0) or result.get("errors"):
                logger.info("Recurring worker result: %s", result)
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("Recurring worker failed")

        await asyncio.sleep(interval)


@asynccontextmanager
async def lifespan(_: FastAPI):
    scheduler_enabled = os.getenv("RUN_RECURRING_SCHEDULER", "true").lower() not in {
        "0",
        "false",
        "no",
        "off",
    }
    worker_task: asyncio.Task | None = None

    if scheduler_enabled:
        worker_task = asyncio.create_task(_recurring_worker())

    try:
        yield
    finally:
        if worker_task is not None:
            worker_task.cancel()
            with suppress(asyncio.CancelledError):
                await worker_task


app = FastAPI(
    title="FinTrack Backend",
    version="1.1.0",
    lifespan=lifespan,
)

origins = [
    origin.strip()
    for origin in os.getenv(
        "CORS_ORIGINS",
        "http://localhost,http://127.0.0.1,http://localhost:3000,http://localhost:5000",
    ).split(",")
    if origin.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(transaction_router)
app.include_router(category_router)
app.include_router(report_router)
app.include_router(wallet_router)
app.include_router(budget_router)
app.include_router(recurring_router)


class UserCreate(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    displayName: str = Field(min_length=1, max_length=100)


@app.get("/health", tags=["System"])
def health_check():
    return {"status": "ok", "service": "fintrack-backend"}


@app.post("/users/{uid}", tags=["Users"])
def create_or_update_user(uid: str, user: UserCreate):
    """Đồng bộ hồ sơ Firebase Auth mà không ghi đè ngày tạo cũ."""
    try:
        user_ref = db.collection("users").document(uid)
        existing = user_ref.get()

        user_data = _model_dump(user)
        user_data.update(
            {
                "id": uid,
                "email": user.email.strip(),
                "displayName": user.displayName.strip(),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }
        )
        if not existing.exists:
            user_data["createdAt"] = firestore.SERVER_TIMESTAMP

        user_ref.set(user_data, merge=True)
        response_data = user_ref.get().to_dict() or {"id": uid}
        return {
            "status": "success",
            "message": "Đã đồng bộ người dùng",
            "data": response_data,
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/users/{uid}", tags=["Users"])
def get_user(uid: str):
    try:
        snapshot = db.collection("users").document(uid).get()
        if not snapshot.exists:
            raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
        return {"status": "success", "data": snapshot.to_dict()}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
