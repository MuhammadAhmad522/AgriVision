import asyncio
import os
import json
from app.services.ai_advisor_service import get_ai_provider, _provider_config
from app.database import get_db
from app.models.db_models import SystemSettings
from dotenv import load_dotenv

load_dotenv()

async def test():
    db_generator = get_db()
    db = next(db_generator)

    def set_settings(mode: str, model: str):
        print(f"\n--- Setting Mode: {mode}, Model: {model} ---")
        setting = db.query(SystemSettings).filter_by(key="ai_configuration").first()
        if not setting:
            setting = SystemSettings(key="ai_configuration", value={})
            db.add(setting)
        
        setting.value = {"mode": mode, "model": model}
        db.commit()

    async def run_provider_test():
        global _provider_config
        # Force re-init to test dynamic loading
        _provider_config = {}
        
        provider = get_ai_provider(db)
        print(f"Provider class initialized: {provider.__class__.__name__}")
        print(f"Provider model set: {getattr(provider, 'model_name', 'N/A')}")
        
        if getattr(provider, 'client', None):
            print(f"Provider client initialized successfully.")
            
        print("Testing summarize_season (1 attempt)...")
        try:
            res = await provider.summarize_season(
                existing_narrative=None,
                new_recommendations=[],
                recommendation_history=[],
                farmer_reported_context=None,
                days_since_planting=None,
                crop_type="wheat"
            )
            print("SUCCESS:", res)
        except Exception as e:
            print("EXPECTED FAILURE (Quota/Billing):", e)

    # Test 1: Free Tier, Gemini 1.5 Flash (might have more quota)
    set_settings("free", "gemini-1.5-flash")
    await run_provider_test()
    
    # Test 2: Vertex Tier, Gemini 1.5 Pro
    set_settings("vertex", "gemini-1.5-pro")
    await run_provider_test()

if __name__ == "__main__":
    asyncio.run(test())
