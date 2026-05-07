import pandas as pd
import joblib
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.metrics import confusion_matrix, roc_curve, auc
from sklearn.preprocessing import label_binarize
from sklearn.cluster import KMeans
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
import os

# Ensure output directory exists
os.makedirs("graphs", exist_ok=True)

# 1. Load Data
df = pd.read_csv("final_dataset_with_alert.csv")

# 2. Feature Engineering
df["RAIN_DIFF"] = df.groupby("LOCATION")["Rainfall"].diff().fillna(0)
df["HUM_RAIN"] = df["Humidity"] * df["Rainfall"]
df["WIND_RAIN"] = df["Windspeed"] * df["Rainfall"]
df["RAIN_LAG"] = df.groupby("LOCATION")["Rainfall"].shift(1).fillna(0)
df["HUM_LAG"] = df.groupby("LOCATION")["Humidity"].shift(1).fillna(0)
df["RAIN_AVG_3"] = df.groupby("LOCATION")["Rainfall"].transform(lambda x: x.rolling(window=3, min_periods=1).mean())

X = df[[
    "Rainfall", "Humidity", "Windspeed", "Tempreature",
    "RAIN_DIFF", "HUM_RAIN", "WIND_RAIN", "RAIN_LAG", "HUM_LAG", "RAIN_AVG_3"
]]

# Self-Learn Labels
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

kmeans = KMeans(n_clusters=3, random_state=42, n_init=10)
cluster_labels = kmeans.fit_predict(X_scaled)

iso_forest = IsolationForest(contamination=0.05, random_state=42, n_jobs=-1)
anomaly_labels = iso_forest.fit_predict(X_scaled)

high_risk_clusters = []
for cluster in range(3):
    cluster_indices = (cluster_labels == cluster)
    avg_rainfall = X.loc[cluster_indices, 'Rainfall'].mean()
    avg_humidity = X.loc[cluster_indices, 'Humidity'].mean()
    if avg_rainfall > X['Rainfall'].quantile(0.75) or avg_humidity > X['Humidity'].quantile(0.75):
        high_risk_clusters.append(cluster)

y_learned = np.zeros(len(X), dtype=int)
for i in range(len(X)):
    if anomaly_labels[i] == -1:
        y_learned[i] = 2
    elif cluster_labels[i] in high_risk_clusters:
        y_learned[i] = 1
    else:
        y_learned[i] = 0

y = pd.Series(y_learned, name="LEARNED_ALERT")

feature_weights = np.ones(X.shape[1])
feature_cols = list(X.columns)
weight_map = {"Rainfall": 5.0, "Humidity": 4.0, "Windspeed": 3.0, "Temperature": 0.5}

for i, col in enumerate(feature_cols):
    if col in weight_map:
        feature_weights[i] = weight_map[col]

X_weighted = X * feature_weights

X_train, X_test, y_train, y_test = train_test_split(X_weighted, y, test_size=0.2, random_state=42, stratify=y)

# Load Model
model = joblib.load('rf_model.pkl')
y_pred = model.predict(X_test)

# Plot 1: Confusion Matrix
plt.figure(figsize=(8, 6))
cm = confusion_matrix(y_test, y_pred)
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', xticklabels=['No Alert', 'Moderate', 'High Alert'], yticklabels=['No Alert', 'Moderate', 'High Alert'])
plt.title('Confusion Matrix')
plt.ylabel('Actual')
plt.xlabel('Predicted')
plt.tight_layout()
plt.savefig('graphs/confusion_matrix.png')
plt.close()

# Plot 2: Feature Importance
importances = model.feature_importances_
indices = np.argsort(importances)[::-1]
names = [feature_cols[i] for i in indices]

plt.figure(figsize=(10, 6))
plt.title("Feature Importance")
plt.bar(range(X.shape[1]), importances[indices], align="center")
plt.xticks(range(X.shape[1]), names, rotation=45, ha='right')
plt.xlim([-1, X.shape[1]])
plt.tight_layout()
plt.savefig('graphs/feature_importance.png')
plt.close()

# Plot 3: Class Distribution
plt.figure(figsize=(8, 6))
sns.countplot(x=y, palette='viridis')
plt.title('Self-Learned Class Distribution')
plt.xticks([0, 1, 2], ['No Alert', 'Moderate', 'High Alert'])
plt.ylabel('Count')
plt.tight_layout()
plt.savefig('graphs/class_distribution.png')
plt.close()

print("Graphs successfully generated in 'graphs/' folder!")
ī