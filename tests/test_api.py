import pytest
from httpx import AsyncClient
from httpx import ASGITransport
from api.main import app

@pytest.mark.asyncio
async def test_home():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.get("/")
    assert response.status_code == 200


@pytest.mark.asyncio
async def test_predict():
    transport = ASGITransport(app=app)
    dummy = {"pixels": [0.0]*64}  # 64 pixels for 8x8 image

    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.post("/predict", json=dummy)

    assert response.status_code == 200