from fastapi import FastAPI

app = FastAPI(title="MLOps AWS PoC")


@app.get("/health")
def health():
    return {"status": "ok"}
