import asyncio
import httpx

async def test_tiles():
    async with httpx.AsyncClient(base_url="http://localhost:8000") as client:
        # Login
        resp = await client.post("/api/auth/login", data={"username": "muhammadahmad522@gmail.com", "password": "Password@123"})
        token = resp.json()["access_token"]
        client.headers["Authorization"] = f"Bearer {token}"
        
        # Get first field
        resp = await client.get("/api/fields")
        fields = resp.json()
        if not fields:
            print("No fields")
            return
        field_id = fields[0]["id"]
        
        layers = ["ndvi", "ndwi", "evi", "truecolor", "falsecolor", "evi2", "nri", "dswi"]
        for layer in layers:
            resp = await client.get(f"/api/fields/{field_id}/satellite/latest/tile/{layer}/12/12/12")
            print(f"{layer}: {resp.status_code}")

asyncio.run(test_tiles())
