# FROM public.ecr.aws/docker/library/python:3.10.1
FROM python:3.10.1

RUN pip install poetry

WORKDIR /app

COPY pyproject.toml ./
COPY poetry.toml ./
COPY poetry.lock ./

RUN poetry install --no-dev

COPY . .

EXPOSE 5002
ENTRYPOINT ["poetry", "run"]
CMD ["gunicorn", "-b[::]:5002", "app:app"]
