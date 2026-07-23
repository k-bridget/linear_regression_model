import io
import os
from typing import Literal, Optional

import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, Field
from sklearn.compose import ColumnTransformer
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error, r2_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "best_model.pkl")
TRAINING_DATA_PATH = os.path.join(BASE_DIR, "violence_data.csv")

CATEGORICAL_FEATURES = [
    "Country", "Gender", "Demographics Question", "Demographics Response", "Question",
]
NUMERIC_FEATURES = ["Survey Year"]
TARGET = "Value"

# App 

app = FastAPI(
    title="IPV Attitude Prediction API",
    description=(
        "Predicts the percentage of a demographic group in a country who believe "
        "intimate partner violence is justified, given demographic and country context. "
        "Built to support SRH rights advocacy and education for women and girls."
    ),
    version="1.0.0",
)
ALLOWED_ORIGINS = [
    "http://localhost:3000",       
    "http://localhost:8080",       
    "http://127.0.0.1:8080",
    "http://localhost:60834/",  
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
)


# Request / response schemas 
class PredictionRequest(BaseModel):
    country: Literal[
        "Afghanistan", "Albania", "Angola", "Armenia", "Azerbaijan", "Bangladesh", "Benin",
        "Bolivia", "Burkina Faso", "Burundi", "Cambodia", "Cameroon", "Chad", "Colombia",
        "Comoros", "Congo", "Congo Democratic Republic", "Cote d'Ivoire", "Dominican Republic",
        "Egypt", "Eritrea", "Eswatini", "Ethiopia", "Gabon", "Gambia", "Ghana", "Guatemala",
        "Guinea", "Guyana", "Haiti", "Honduras", "India", "Indonesia", "Jordan", "Kenya",
        "Kyrgyz Republic", "Lesotho", "Liberia", "Madagascar", "Malawi", "Maldives", "Mali",
        "Moldova", "Morocco", "Mozambique", "Myanmar", "Namibia", "Nepal", "Nicaragua", "Niger",
        "Nigeria", "Pakistan", "Peru", "Philippines", "Rwanda", "Sao Tome and Principe",
        "Senegal", "Sierra Leone", "South Africa", "Tajikistan", "Tanzania", "Timor-Leste",
        "Togo", "Turkey", "Turkmenistan", "Uganda", "Ukraine", "Yemen", "Zambia", "Zimbabwe",
    ] = Field(..., description="Country covered by the DHS survey")

    gender: Literal["F", "M"] = Field(..., description="Respondent gender")

    demographics_question: Literal[
        "Age", "Education", "Employment", "Marital status", "Residence"
    ] = Field(..., description="Which demographic dimension is being reported")

    demographics_response: Literal[
        "15-24", "25-34", "35-49", "Employed for cash", "Employed for kind", "Higher",
        "Married or living together", "Never married", "No education", "Primary", "Rural",
        "Secondary", "Unemployed", "Urban", "Widowed, divorced, separated",
    ] = Field(..., description="Specific category within the demographic dimension above")

    question: Literal[
        "... for at least one specific reason", "... if she argues with him",
        "... if she burns the food", "... if she goes out without telling him",
        "... if she neglects the children", "... if she refuses to have sex with him",
    ] = Field(..., description="The IPV justification scenario asked about")

    survey_year: int = Field(
        ..., ge=2000, le=2025,
        description="Survey year. 2000-2018 is the range seen in training data; up to 2025 "
                    "is allowed for near-future survey rounds, but predictions outside the "
                    "training range should be treated with reduced confidence.",
    )

    class Config:
        json_schema_extra = {
            "example": {
                "country": "Afghanistan",
                "gender": "F",
                "demographics_question": "Education",
                "demographics_response": "Higher",
                "question": "... if she burns the food",
                "survey_year": 2015,
            }
        }


class PredictionResponse(BaseModel):
    predicted_value: float = Field(
        ..., description="Predicted % of the specified demographic group who agree IPV is "
                          "justified for the given reason"
    )
    model_used: str


class RetrainResponse(BaseModel):
    message: str
    rows_used_for_training: int
    test_rmse: float
    test_r2: float

# Routes
@app.get("/", include_in_schema=False)
def root():
    """Redirect the bare root URL to the interactive Swagger UI docs."""
    return RedirectResponse(url="/docs")


@app.post("/predict", response_model=PredictionResponse)
def predict(request: PredictionRequest):
    """Predict the % of a demographic group expected to agree IPV is justified."""
    if not os.path.exists(MODEL_PATH):
        raise HTTPException(status_code=503, detail="Model file not found on server.")

    pipe = joblib.load(MODEL_PATH)

    input_df = pd.DataFrame([{
        "Country": request.country,
        "Gender": request.gender,
        "Demographics Question": request.demographics_question,
        "Demographics Response": request.demographics_response,
        "Question": request.question,
        "Survey Year": request.survey_year,
    }])

    try:
        prediction = float(pipe.predict(input_df)[0])
    except Exception as exc:  # pragma: no cover
        raise HTTPException(status_code=500, detail=f"Prediction failed: {exc}") from exc

    return PredictionResponse(predicted_value=round(prediction, 2), model_used=os.path.basename(MODEL_PATH))


@app.post("/retrain", response_model=RetrainResponse)
def retrain(file: Optional[UploadFile] = File(None)):
    if not os.path.exists(TRAINING_DATA_PATH):
        raise HTTPException(status_code=503, detail="Base training dataset not found on server.")

    base_df = pd.read_csv(TRAINING_DATA_PATH)

    if file is not None:
        try:
            contents = file.file.read()
            new_df = pd.read_csv(io.BytesIO(contents))
        except Exception as exc:
            raise HTTPException(status_code=400, detail=f"Could not parse uploaded CSV: {exc}") from exc

        required_cols = {"Country", "Gender", "Demographics Question", "Demographics Response",
                          "Question", "Survey Year", "Value"}
        if not required_cols.issubset(set(new_df.columns)):
            missing = required_cols - set(new_df.columns)
            raise HTTPException(status_code=400, detail=f"Uploaded CSV missing columns: {missing}")

        combined_df = pd.concat([base_df, new_df], ignore_index=True, sort=False)
    else:
        combined_df = base_df

    combined_df = combined_df.dropna(subset=["Value"]).reset_index(drop=True)
    combined_df["Survey Year"] = pd.to_datetime(combined_df["Survey Year"]).dt.year

    X = combined_df[CATEGORICAL_FEATURES + NUMERIC_FEATURES]
    y = combined_df[TARGET]
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    preprocessor = ColumnTransformer(transformers=[
        ("cat", OneHotEncoder(handle_unknown="ignore"), CATEGORICAL_FEATURES),
        ("num", StandardScaler(), NUMERIC_FEATURES),
    ])
    pipe = Pipeline([("preprocess", preprocessor), ("model", LinearRegression())])
    pipe.fit(X_train, y_train)

    preds = pipe.predict(X_test)
    rmse = mean_squared_error(y_test, preds) ** 0.5
    r2 = r2_score(y_test, preds)

    joblib.dump(pipe, MODEL_PATH)

    return RetrainResponse(
        message="Model retrained and deployed successfully.",
        rows_used_for_training=len(combined_df),
        test_rmse=round(rmse, 3),
        test_r2=round(r2, 3),
    )