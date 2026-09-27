# FARCI — MLflow avec dépendances pinées
FROM mlflow/mlflow:3.16.1

RUN pip install --no-cache-dir \
    scikit-learn==1.9.1 \
    pandas==3.0.6

EXPOSE 5000

CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000"]
