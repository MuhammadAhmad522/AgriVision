"""One-off / re-runnable ingestion script for the AgriVision agronomy knowledge base.

Uploads the curated corpus below to the GCS bucket backing the Vertex AI Search data store
(VERTEX_SEARCH_DATASTORE) and imports it as documents with structured metadata (crop, region,
approved, title, url) so VertexSearchKnowledgeProvider can retrieve and cite it.

Every excerpt here must be real text drawn from a genuinely high-quality, approved source
(APPROVED_SOURCE_PREFIXES in app/services/ai_advisor_service.py) — never fabricated. To add a
new crop or topic: fetch real source text, add a CorpusDoc entry below (or a new list item, no
crop is hardcoded elsewhere), and re-run this script — it's idempotent (INCREMENTAL
reconciliation matches on `id`, so re-running with the same ids updates rather than duplicates).

Usage: python scripts/ingest_agronomy_knowledge.py
"""
import sys
import os
import json
from dataclasses import dataclass

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from app.core.config import settings


@dataclass
class CorpusDoc:
    id: str
    crop: str  # lowercase — VertexSearchKnowledgeProvider matches crop.lower()
    title: str
    url: str  # must match one of APPROVED_SOURCE_PREFIXES
    region: str
    text: str


CORPUS: list[CorpusDoc] = [
    CorpusDoc(
        id="wheat-irrigation",
        crop="wheat",
        title="Wheat Growth Stages and Water Requirements (FAO Irrigation and Drainage Paper 56)",
        url="https://www.fao.org/4/x0490e/x0490e0b.htm",
        region="Global",
        text=(
            "Wheat growth stages and water requirements (FAO Irrigation and Drainage Paper 56, crop "
            "coefficient tables).\n\n"
            "Spring wheat growth stage lengths: initial stage about 20 days, development stage about "
            "50 days, mid-season stage about 60 days, late season stage about 30 days - a total growing "
            "period around 160 days. Winter wheat follows a similar stage breakdown but spans dormancy; "
            "where soils are frozen during the initial stage the crop coefficient is lower (around 0.4) "
            "than where soils remain non-frozen (around 0.7), reflecting different soil moisture "
            "behavior during dormancy.\n\n"
            "Crop coefficients (Kc) for spring wheat: Kc initial about 0.3, Kc mid-season about 1.15, "
            "Kc late-season about 0.25-0.41 depending on whether the field is irrigated up to or before "
            "harvest. Maximum crop height is about 1 meter.\n\n"
            "Water use follows ETc = Kc x ETo (crop evapotranspiration equals the crop coefficient times "
            "reference evapotranspiration), meaning wheat's water demand is lowest at planting and "
            "emergence, rises through tillering and stem elongation to peak around heading and flowering "
            "(mid-season), then declines again as the crop matures toward harvest."
        ),
    ),
    CorpusDoc(
        id="wheat-pests",
        crop="wheat",
        title="Wheat and Small Grains Pest, Disease, and Weed Monitoring (UC IPM)",
        url="https://ipm.ucanr.edu/agriculture/small-grains/",
        region="Global",
        text=(
            "Wheat and small grains pest, disease, and weed monitoring topics (UC Statewide IPM "
            "Program, small grains guidelines).\n\n"
            "Invertebrate pests to monitor in wheat include several aphid species (bird cherry-oat "
            "aphid, corn leaf aphid, English grain aphid, greenbug, rose-grain aphid, Russian wheat "
            "aphid), armyworms, black grass bug, grasshoppers, mites, range crane fly, stink bugs, "
            "wheat stem maggot, and wireworms.\n\n"
            "Plant diseases to monitor include bacterial blights, barley stripe, barley yellow dwarf, "
            "black point, common root rot and scab, covered smut, ergot, Karnal bunt of wheat, leaf "
            "blotch, leaf/stem/stripe rusts, leaf scald, loose smut, net blotch, powdery mildew, "
            "Septoria tritici blotch, and take-all.\n\n"
            "Weed management guidance covers integrated weed management approaches and special / "
            "hard-to-control weed problems specific to small grains.\n\n"
            "General principle: because wheat pest and disease pressure varies by growth stage and "
            "local conditions, field-level monitoring across the season (not a single inspection) "
            "combined with locally adapted variety choice and integrated management is the standard "
            "approach, rather than relying on any single control method."
        ),
    ),
    CorpusDoc(
        id="rice-irrigation",
        crop="rice",
        title="Rice Growth Stages and Water Requirements (FAO Irrigation and Drainage Paper 56)",
        url="https://www.fao.org/4/x0490e/x0490e0b.htm",
        region="Global",
        text=(
            "Rice growth stages and water requirements (FAO Irrigation and Drainage Paper 56, crop "
            "coefficient tables).\n\n"
            "Typical rice growth stage lengths: about 30 days initial, 30 days development, 60 days "
            "mid-season, and 30 days late season for December or May plantings in tropical and "
            "Mediterranean climates (roughly 150 days total); a May planting in some tropical regions "
            "runs closer to 30, 30, 80, 40 days (about 180 days total).\n\n"
            "Crop coefficients (Kc) for rice: Kc initial about 1.05, Kc mid-season about 1.20, Kc "
            "late-season about 0.90 down to 0.60 depending on harvest timing. Maximum crop height is "
            "about 1 meter. The relatively high initial coefficient reflects evaporation from the "
            "standing water layer in paddy fields, which dominates early-season water use before the "
            "canopy closes.\n\n"
            "Practical implication: rice water demand is driven as much by maintaining the "
            "standing-water layer early in the season as by the crop's own transpiration, and water "
            "management (not just rainfall/irrigation volume) should account for paddy evaporation "
            "losses through the initial and development stages."
        ),
    ),
    CorpusDoc(
        id="rice-blast",
        crop="rice",
        title="Rice Blast Disease: Symptoms, Timing, and Monitoring (UC IPM)",
        url="https://ipm.ucanr.edu/agriculture/rice/rice-blast/",
        region="Global",
        text=(
            "Rice blast disease: symptoms, timing, and monitoring (UC Statewide IPM Program).\n\n"
            "Leaf symptoms: lesions on the leaf are usually diamond-shaped with a gray or white center "
            "and a brown or reddish-brown border, typically 0.4-0.6 inches long. Lesions can coalesce "
            "and kill young plants through the tillering stage.\n\n"
            "Collar infection: brown discoloration forms at the junction of the leaf blade and the "
            "sheath, often resulting in death of the leaf.\n\n"
            "Stem node infection: infected nodes become brown or black and can kill the entire stem "
            "above the point of infection.\n\n"
            "Panicle (neck) infection: the most damaging form occurs at the panicle neck, causing "
            "\"neck rot\" or \"rotten neck\" symptoms. Early infection can result in completely blank "
            "panicles with unfilled kernels; later infection causes incomplete grain filling and poor "
            "milling quality.\n\n"
            "Seasonal timing: leaf blast typically increases early in the season then declines as "
            "leaves mature; neck blast risk peaks during the heading stage, particularly under "
            "conditions that favor disease spread. Under favorable conditions the disease can complete "
            "a full infection cycle in about a week.\n\n"
            "Monitoring guidance: monitor multiple locations throughout the field for leaf lesions, and "
            "intensify monitoring as plants approach the boot stage. Treatment decisions should weigh "
            "disease progress, growth stage, environmental conditions, and variety susceptibility - "
            "resistant varieties substantially reduce risk where available."
        ),
    ),
    CorpusDoc(
        id="rice-pests-overview",
        crop="rice",
        title="Rice Pest, Disease, and Weed Monitoring Topics (UC IPM)",
        url="https://ipm.ucanr.edu/agriculture/rice/",
        region="Global",
        text=(
            "Rice pest, disease, and weed monitoring topics (UC Statewide IPM Program, rice "
            "guidelines).\n\n"
            "Invertebrate pests to monitor include armyworms, aster leafhoppers, crayfish, rice "
            "leafminers, rice seed midges, rice water weevils, and tadpole shrimp; mosquito management "
            "in the agricultural setting is also addressed given standing-water conditions.\n\n"
            "Plant diseases to monitor include aggregate sheath spot, bakanae, kernel smut, rice blast, "
            "seed rot and seedling diseases, and stem rot.\n\n"
            "Weed management guidance covers identification, integrated control strategies, problem "
            "weed species, herbicide susceptibility, and treatment options.\n\n"
            "General guidance: rice developmental stage and the treatment-period window during which "
            "control is most effective should guide the timing of any intervention, rather than "
            "treating on a fixed calendar date - and product choice should account for relative "
            "toxicity to natural enemies and pollinators active in and around the paddy."
        ),
    ),
    CorpusDoc(
        id="sugarcane-irrigation",
        crop="sugarcane",
        title="Sugarcane Growth Stages and Water Requirements (FAO Irrigation and Drainage Paper 56)",
        url="https://www.fao.org/4/x0490e/x0490e0b.htm",
        region="Global",
        text=(
            "Sugarcane growth stages and water requirements (FAO Irrigation and Drainage Paper 56, "
            "crop coefficient tables).\n\n"
            "Sugarcane growth stage lengths vary substantially by climate and whether the crop is "
            "virgin (newly planted) cane or ratoon (regrown from stubble). Virgin cane in low latitudes "
            "runs roughly 35, 60, 190, 120 days across initial/development/mid-season/late-season "
            "stages (about 405 days total); in the tropics roughly 50, 70, 220, 140 days (about 480 "
            "days total); in longer-season regions such as Hawaii roughly 75, 105, 330, 210 days (about "
            "720 days total). Ratoon cane in low latitudes is shorter, roughly 25, 70, 135, 50 days "
            "(about 280 days total).\n\n"
            "Crop coefficients (Kc) for sugarcane: Kc initial about 0.40, Kc mid-season about 1.25, Kc "
            "late-season about 0.75. Maximum crop height is about 3 meters, substantially taller than "
            "wheat or rice.\n\n"
            "Practical implication: sugarcane's growing cycle is far longer than wheat or rice (often "
            "approaching or exceeding a full year for virgin cane), so water and nutrient planning must "
            "account for a much longer mid-season period of peak demand, and ratoon crops should be "
            "planned and irrigated differently from virgin plantings given their shorter cycle."
        ),
    ),
    CorpusDoc(
        id="sugarcane-fertilizer",
        crop="sugarcane",
        title="Sugarcane Nitrogen and Fertilizer Requirements (University of Florida IFAS Extension)",
        url="https://ask.ifas.ufl.edu/publication/SC028",
        region="Global",
        text=(
            "Sugarcane nitrogen and fertilizer requirements and timing (University of Florida IFAS "
            "Extension, sugarcane nutritional requirements publication).\n\n"
            "Nitrogen need depends heavily on soil organic matter content. On muck soils (greater than "
            "20% organic matter), no nitrogen fertilizer is typically recommended, because warm-season "
            "mineralization of the organic matter releases sufficient nitrogen naturally. On sand soils "
            "(less than 6% organic matter), recommended rates are far higher - around 220 lb N/acre for "
            "plant cane and 200 lb N/acre for ratoon crops - applied as multiple split applications "
            "(about five for plant cane, four for ratoons) with no more than about 50 lb of soluble N "
            "per acre in any single application. Transitional soils fall in between: mucky sands "
            "(6-12% organic matter) around 110 lb N/acre in two splits, sandy mucks (13-20% organic "
            "matter) around 30 lb N/acre.\n\n"
            "Timing rationale: split applications matter most on sandy soils because of nitrogen "
            "leaching risk during heavy rainfall periods, since low-organic-matter sandy soils hold "
            "much less nitrogen-supplying capacity than organic soils. A late-season nitrogen deficit "
            "can also help sugar ripening on mineral soils, though this effect is generally not "
            "achievable on high-organic-matter soils.\n\n"
            "Practical implication: fertilizer recommendations for sugarcane cannot be generalized "
            "across a region without accounting for local soil organic matter - the same nitrogen rate "
            "that is excessive on muck soil may be substantially under-supplying a sandy field."
        ),
    ),
]


def ingest():
    import google.auth
    from google.auth.transport.requests import AuthorizedSession
    from google.cloud import storage

    project = settings.GOOGLE_CLOUD_PROJECT.strip()
    datastore = settings.VERTEX_SEARCH_DATASTORE.strip()
    if not project or not datastore:
        print("ERROR: GOOGLE_CLOUD_PROJECT and VERTEX_SEARCH_DATASTORE must be set.")
        sys.exit(1)
    bucket_name = f"{project}-agronomy-knowledge"

    print(f"Uploading {len(CORPUS)} documents to gs://{bucket_name}/corpus/ ...")
    storage_client = storage.Client(project=project)
    bucket = storage_client.bucket(bucket_name)
    manifest_lines = []
    for doc in CORPUS:
        blob = bucket.blob(f"corpus/{doc.id}.txt")
        blob.upload_from_string(doc.text, content_type="text/plain")
        manifest_lines.append(json.dumps({
            "id": doc.id,
            "structData": {
                "crop": doc.crop.lower(),
                "region": doc.region,
                "approved": True,
                "title": doc.title,
                "url": doc.url,
            },
            "content": {"mimeType": "text/plain", "uri": f"gs://{bucket_name}/corpus/{doc.id}.txt"},
        }))
        print(f"  uploaded {doc.id} ({doc.crop})")

    manifest_blob = bucket.blob("corpus-manifest.jsonl")
    manifest_blob.upload_from_string("\n".join(manifest_lines) + "\n", content_type="application/json")
    print("Uploaded manifest.")

    print("Importing into Discovery Engine data store ...")
    credentials, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    session = AuthorizedSession(credentials)
    endpoint = (
        f"https://discoveryengine.googleapis.com/v1/projects/{project}/locations/"
        f"{settings.GOOGLE_CLOUD_LOCATION}/collections/default_collection/dataStores/"
        f"{datastore}/branches/0/documents:import"
    )
    response = session.post(endpoint, json={
        "gcsSource": {
            "inputUris": [f"gs://{bucket_name}/corpus-manifest.jsonl"],
            "dataSchema": "document",
        },
        "reconciliationMode": "INCREMENTAL",
    })
    response.raise_for_status()
    print("Import started (async):")
    print(json.dumps(response.json(), indent=2))
    print("\nIndexing can take several minutes. Check the operation above, or re-query "
          "VertexSearchKnowledgeProvider directly once it's done.")


if __name__ == "__main__":
    ingest()
