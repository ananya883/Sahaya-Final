import pandas as pd
import joblib
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, precision_score, recall_score, f1_score
from sklearn.cluster import KMeans
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
import numpy as np
df = pd.read_csv("final_dataset_with_alert.csv")


# Rainfall change
df["RAIN_DIFF"] = df.groupby("LOCATION")["Rainfall"].diff().fillna(0)

# Interaction features
df["HUM_RAIN"] = df["Humidity"] * df["Rainfall"]
df["WIND_RAIN"] = df["Windspeed"] * df["Rainfall"]

# Lagged featuresīīī
df["RAIN_LAG"] = df.groupby("LOCATION")["Rainfall"].shift(1).fillna(0)
df["HUM_LAG"] = df.groupby("LOCATION")["Humidity"].shift(1).fillna(0)

# Rolling average
df["RAIN_AVG_3"] = df.groupby("LOCATION")["Rainfall"].transform(
    lambda x: x.rolling(window=3, min_periods=1).mean()
)


X = df[[
    "Rainfall",
    "Humidity",
    "Windspeed",
    "Tempreature",
    "RAIN_DIFF",
    "HUM_RAIN",
    "WIND_RAIN",
    "RAIN_LAG",
    "HUM_LAG",
    "RAIN_AVG_3"
]]
print("\n🧠 Self-Learning Phase: Discovering patterns without predefined labels...")


scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# 1. K-Means Clustering to find general weather patterns
kmeans = KMeans(n_clusters=3, random_state=42, n_init=10)
cluster_labels = kmeans.fit_predict(X_scaled)

# 2. Isolation Forest to find extreme weather anomalies
iso_forest = IsolationForest(contamination=0.05, random_state=42, n_jobs=-1)
anomaly_labels = iso_forest.fit_predict(X_scaled)

# Determine inherently high-risk clusters based on Rainfall and Humidity
high_risk_clusters = []
for cluster in range(3):
    cluster_indices = (cluster_labels == cluster)
    avg_rainfall = X.loc[cluster_indices, 'Rainfall'].mean()
    avg_humidity = X.loc[cluster_indices, 'Humidity'].mean()
    if avg_rainfall > X['Rainfall'].quantile(0.75) or avg_humidity > X['Humidity'].quantile(0.75):
        high_risk_clusters.append(cluster)

# Assign self-learned alert levels
# 0 = Normal, 1 = Moderate (High risk cluster), 2 = Extreme/Anomaly
y_learned = np.zeros(len(X), dtype=int)
for i in range(len(X)):
    if anomaly_labels[i] == -1:
        y_learned[i] = 2
    elif cluster_labels[i] in high_risk_clusters:
        y_learned[i] = 1
    else:
        y_learned[i] = 0

# Use self-learned labels as our target for Random Forest
y = pd.Series(y_learned, name="LEARNED_ALERT")

# -----------------------------
# STEP 3.6: Feature Priority Weights 
# -----------------------------
# To enforce importance: Rainfall > Humidity > Windspeed > Temperature
# We scale the features explicitly before feeding them to the Random Forest
# This acts as a multiplier bias to steer the tree splits
feature_weights = np.ones(X.shape[1])
feature_cols = list(X.columns)

# Assign custom weights to steer the RF model
weight_map = {
    "Rainfall": 5.0,
    "Humidity": 4.0,
    "Windspeed": 3.0,
    "Temperature": 0.5   # De-emphasized
}

for i, col in enumerate(feature_cols):
    if col in weight_map:
        feature_weights[i] = weight_map[col]

X_weighted = X * feature_weights

# Check new class distribution
print("\n📈 Self-Learned Class Distribution:")
print(y.value_counts())
print(f"Class proportions:\n{y.value_counts(normalize=True)}")

# ----------------------------- 
# STEP 4: Split data (Stratified)
# ----------------------------- 
X_train, X_test, y_train, y_test = train_test_split(
    X_weighted, y,
    test_size=0.2,
    random_state=42,
    stratify=y
)

print(f"\n📊 Data Split:")
print(f"Training set: {X_train.shape[0]} samples")
print(f"Test set: {X_test.shape[0]} samples")
print(f"Features: {X_train.shape[1]}")

# ----------------------------- 
# STEP 5: Train Random Forest Model
# ----------------------------- 
model = RandomForestClassifier(
    n_estimators=300,
    max_depth=15,
    min_samples_split=5,
    min_samples_leaf=2,
    max_features='sqrt',
    class_weight="balanced",
    random_state=42,
    n_jobs=-1,
    verbose=1
)

print("\n🔄 Training Random Forest Model...")
model.fit(X_train, y_train)
print("✅ Model trained!")

# ----------------------------- 
# STEP 6: Cross-Validation
# ----------------------------- 
print("\n📊 Performing 5-Fold Cross-Validation...")
cv_scores = cross_val_score(model, X_train, y_train, cv=5, scoring='accuracy')
print(f"CV scores: {[f'{score:.4f}' for score in cv_scores]}")
print(f"Mean CV Accuracy: {cv_scores.mean():.4f} (+/- {cv_scores.std():.4f})")

# ----------------------------- 
# STEP 7: Make Predictions
# ----------------------------- 
y_pred = model.predict(X_test)
y_pred_proba = model.predict_proba(X_test)

# ----------------------------- 
# STEP 8: Comprehensive Evaluation
# ----------------------------- 
print("\n" + "="*60)
print("MODEL PERFORMANCE METRICS")
print("="*60)

# Accuracy
accuracy = accuracy_score(y_test, y_pred)
print(f"\n✅ Overall Accuracy: {accuracy:.4f}")

# Precision, Recall, F1 per class
precision = precision_score(y_test, y_pred, average='weighted', zero_division=0)
recall = recall_score(y_test, y_pred, average='weighted', zero_division=0)
f1 = f1_score(y_test, y_pred, average='weighted', zero_division=0)

print(f"📊 Weighted Precision: {precision:.4f}")
print(f"📊 Weighted Recall: {recall:.4f}")
print(f"📊 Weighted F1-Score: {f1:.4f}")

# Classification Report
print("\n📋 Detailed Classification Report:")
print(classification_report(y_test, y_pred, target_names=['No Alert', 'Moderate Alert', 'High Alert'], zero_division=0))

# Confusion Matrix
cm = confusion_matrix(y_test, y_pred)
print("\n🔀 Confusion Matrix:")
print(cm)

# ----------------------------- 
# STEP 9: Feature Importance
# ----------------------------- 
feature_names = X.columns
importances = model.feature_importances_
feature_importance_df = pd.DataFrame({
    'Feature': feature_names,
    'Importance': importances
}).sort_values('Importance', ascending=False)

print("\n🔥 Feature Importance (Top 10):")
print(feature_importance_df.head(10).to_string(index=False))

# ----------------------------- 
# STEP 10: Save Model
# ----------------------------- 
joblib.dump(model, 'rf_model.pkl')
print("\n✅ Model saved as 'rf_model.pkl'")

# Save feature names for future predictions
joblib.dump(feature_names, 'feature_names.pkl')
print("✅ Feature names saved as 'feature_names.pkl'")

print("\n" + "="*60)
print("TRAINING COMPLETE!")
print("="*60)
