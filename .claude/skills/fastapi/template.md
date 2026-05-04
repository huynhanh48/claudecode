# Boilerplate templates

Copy these files verbatim when bootstrapping a new project. `<Resource>` / `<resource>` are placeholders to substitute per-feature.

---

## `main.py`

```python
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.exc import SQLAlchemyError

from app.db.database import engine
from app.exception import HttpException
from app.models.base import Base
from app.routes import RootRouter

logger = logging.getLogger(__name__)


def _bootstrap_database_schema() -> None:
    Base.metadata.create_all(bind=engine)


@asynccontextmanager
async def lifespan(app: FastAPI):
    _bootstrap_database_schema()
    yield


app = FastAPI(lifespan=lifespan)
app.add_middleware(GZipMiddleware, minimum_size=1000)


@app.exception_handler(HttpException)
async def http_exception_handler(request: Request, exc: HttpException):
    return JSONResponse(status_code=exc.status_code, content={'message': exc.message})


@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_exception_handler(request: Request, exc: SQLAlchemyError):
    logger.exception('Unhandled SQLAlchemy error')
    return JSONResponse(
        status_code=500,
        content={'message': 'Database error. Please try again later.'},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    logger.exception('Unhandled exception')
    return JSONResponse(
        status_code=500,
        content={'message': 'Internal server error'},
    )


app.include_router(RootRouter)


if __name__ == '__main__':
    import uvicorn

    uvicorn.run('main:app', host='0.0.0.0', port=8000, reload=True)
```

The three handlers are intentional:

- **`HttpException`** (domain hierarchy from `app/exception/`) → JSON with the safe `message` field set by the service.
- **`SQLAlchemyError`** → generic 500. Server-side log only. **Never** include `str(exc)` in the response — DB messages can leak schema or PII.
- **`Exception`** → catch-all 500. This is what makes `try/except Exception` in services redundant: any uncaught exception lands here, gets logged with traceback, and returns a generic message.

---

## `app/core/config.py`

Two flavors. Pick **A** for SQLite / local-file deployments, **B** for Postgres.

### A) SQLite-friendly default (single-file deployment)

```python
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env', extra='ignore')

    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = 'HS256'
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    DATABASE_URL: str = 'sqlite:///./app.db'


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
```

### B) Postgres with composed URL

```python
from functools import lru_cache
from urllib.parse import quote_plus

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env', extra='ignore')

    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = 'HS256'
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    DATABASE_URL: str = ''
    POSTGRES_HOST: str = 'localhost'
    POSTGRES_PORT: int = 5432
    POSTGRES_USER: str = 'postgres'
    POSTGRES_PASSWORD: str = ''
    POSTGRES_DB: str = ''

    @model_validator(mode='after')
    def build_database_url(self) -> 'Settings':
        if self.DATABASE_URL:
            return self
        if not self.POSTGRES_DB:
            raise ValueError(
                'DATABASE_URL is required, or set POSTGRES_DB with the other POSTGRES_* variables.'
            )
        password = quote_plus(self.POSTGRES_PASSWORD)
        self.DATABASE_URL = (
            f'postgresql+psycopg2://{self.POSTGRES_USER}:{password}'
            f'@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}'
        )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
```

---

## `app/core/__init__.py`

```python
from .config import get_settings, settings

__all__ = ['settings', 'get_settings']
```

---

## `app/db/database.py`

```python
import logging

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core import settings

# Import every model module so SQLAlchemy mappings are registered at startup.
# Add new resources here:
#   import app.models.<resource>  # noqa: F401

logger = logging.getLogger(__name__)

connect_args: dict = (
    {'check_same_thread': False} if settings.DATABASE_URL.startswith('sqlite') else {}
)

engine = create_engine(settings.DATABASE_URL, connect_args=connect_args, future=True)
session = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def get_db():
    db = session()
    try:
        yield db
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
```

---

## `app/exception/httpexception.py`

```python
from fastapi import status


class HttpException(Exception):
    def __init__(self, status_code: int, message: str):
        self.status_code = status_code
        self.message = message
        super().__init__(self.message, self.status_code)


class BadRequestException(HttpException):
    def __init__(self, message: str = 'Bad Request'):
        super().__init__(status_code=status.HTTP_400_BAD_REQUEST, message=message)


class UnauthorizedException(HttpException):
    def __init__(self, message: str = 'Unauthorized'):
        super().__init__(status_code=status.HTTP_401_UNAUTHORIZED, message=message)


class ForbiddenException(HttpException):
    def __init__(self, message: str = 'Forbidden'):
        super().__init__(status_code=status.HTTP_403_FORBIDDEN, message=message)


class NotFoundException(HttpException):
    def __init__(self, message: str = 'Not Found'):
        super().__init__(status_code=status.HTTP_404_NOT_FOUND, message=message)


class InternalServerErrorException(HttpException):
    def __init__(self, message: str = 'Internal Server Error'):
        super().__init__(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, message=message)
```

---

## `app/exception/__init__.py`

```python
from .httpexception import (
    BadRequestException,
    ForbiddenException,
    HttpException,
    InternalServerErrorException,
    NotFoundException,
    UnauthorizedException,
)

__all__ = [
    'HttpException',
    'BadRequestException',
    'UnauthorizedException',
    'ForbiddenException',
    'NotFoundException',
    'InternalServerErrorException',
]
```

---

## `app/models/base.py`

```python
from datetime import datetime

from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class DateTime:
    created_at: Mapped[datetime] = mapped_column(nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )
```

---

## `app/lib/bcrypto.py`

```python
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=['bcrypt'], deprecated='auto')


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plaintext_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plaintext_password, hashed_password)
```

---

## `app/lib/token.py`

```python
from datetime import datetime, timedelta

import jwt

from app.core import settings
from app.exception import UnauthorizedException


def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (
        expires_delta or timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({'exp': expire})
    return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> dict:
    try:
        payload = jwt.decode(
            token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM]
        )
        if payload.get('sub') is None:
            raise UnauthorizedException(message='Subject not found in token')
        return payload
    except jwt.ExpiredSignatureError as e:
        raise UnauthorizedException(message='Token has expired') from e
    except jwt.InvalidTokenError as e:
        raise UnauthorizedException(message='Invalid token') from e
```

---

## `app/lib/__init__.py`

```python
from .bcrypto import hash_password, verify_password
from .token import create_access_token, decode_access_token

__all__ = [
    'hash_password',
    'verify_password',
    'create_access_token',
    'decode_access_token',
]
```

---

## `app/routes/__init__.py`

```python
from fastapi import APIRouter

# Import routers as you add resources:
#   from .<resource> import <resource>Router

RootRouter = APIRouter()

# RootRouter.include_router(<resource>Router, prefix='/api/<resources>')
```

---

## Per-resource templates

### `app/models/<resource>.py`

```python
from sqlalchemy import Text
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base, DateTime


class <Resource>(Base, DateTime):
    __tablename__ = '<resources>'

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=True)
    deleted: Mapped[bool] = mapped_column(default=False, nullable=False)
```

### `app/schema/<resource>.py`

```python
from datetime import datetime

from pydantic import BaseModel


class <Resource>Create(BaseModel):
    name: str
    description: str | None = None


class <Resource>Update(BaseModel):
    name: str | None = None
    description: str | None = None


class <Resource>Response(BaseModel):
    id: int
    name: str
    description: str | None = None
    deleted: bool
    created_at: datetime
    updated_at: datetime

    model_config = {'from_attributes': True}
```

### `app/repositories/<resource>.py`

```python
from sqlalchemy import desc
from sqlalchemy.orm import Session

from app.models.<resource> import <Resource>
from app.schema.<resource> import <Resource>Create, <Resource>Update


class <Resource>Repository:
    def __init__(self, db: Session):
        self.db = db

    def get_all(self, skip: int = 0, limit: int = 100) -> list[<Resource>]:
        return (
            self.db.query(<Resource>)
            .filter(<Resource>.deleted.is_(False))
            .order_by(desc(<Resource>.created_at))
            .offset(skip)
            .limit(limit)
            .all()
        )

    def get_by_id(self, id_: int) -> <Resource> | None:
        return (
            self.db.query(<Resource>)
            .filter(<Resource>.id == id_, <Resource>.deleted.is_(False))
            .first()
        )

    def create(self, data: <Resource>Create) -> <Resource>:
        instance = <Resource>(**data.model_dump())
        self.db.add(instance)
        self.db.commit()
        self.db.refresh(instance)
        return instance

    def update(self, id_: int, data: <Resource>Update) -> <Resource> | None:
        instance = self.get_by_id(id_)
        if not instance:
            return None
        for key, value in data.model_dump(exclude_unset=True).items():
            setattr(instance, key, value)
        self.db.commit()
        self.db.refresh(instance)
        return instance

    def delete(self, id_: int) -> <Resource> | None:
        instance = self.get_by_id(id_)
        if not instance:
            return None
        instance.deleted = True
        self.db.commit()
        return instance
```

### `app/services/<resource>.py`

```python
from fastapi import Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.exception import NotFoundException
from app.repositories.<resource> import <Resource>Repository
from app.schema.<resource> import <Resource>Create, <Resource>Response, <Resource>Update


class <Resource>Service:
    def __init__(self, db: Session = Depends(get_db)):
        self.db = db
        self.repository = <Resource>Repository(db=self.db)

    def get_all(self, skip: int = 0, limit: int = 100) -> list[<Resource>Response]:
        return [
            <Resource>Response.model_validate(item)
            for item in self.repository.get_all(skip=skip, limit=limit)
        ]

    def get_by_id(self, id_: int) -> <Resource>Response:
        instance = self.repository.get_by_id(id_)
        if not instance:
            raise NotFoundException(message='<Resource> not found')
        return <Resource>Response.model_validate(instance)

    def create(self, data: <Resource>Create) -> <Resource>Response:
        return <Resource>Response.model_validate(self.repository.create(data))

    def update(self, id_: int, data: <Resource>Update) -> <Resource>Response:
        instance = self.repository.update(id_, data)
        if not instance:
            raise NotFoundException(message='<Resource> not found')
        return <Resource>Response.model_validate(instance)

    def delete(self, id_: int) -> dict:
        if not self.repository.delete(id_):
            raise NotFoundException(message='<Resource> not found')
        return {'message': '<Resource> deleted'}
```

### `app/routes/<resource>.py`

```python
from fastapi import APIRouter, Depends

from app.schema.<resource> import <Resource>Create, <Resource>Response, <Resource>Update
from app.services.<resource> import <Resource>Service

<resource>Router = APIRouter(tags=['<resources>'])


@<resource>Router.get('/', response_model=list[<Resource>Response], summary='List <resources>')
def list_<resources>(skip: int = 0, limit: int = 100, service: <Resource>Service = Depends()):
    return service.get_all(skip=skip, limit=limit)


@<resource>Router.get('/{id_}', response_model=<Resource>Response, summary='Get <resource> by id')
def get_<resource>(id_: int, service: <Resource>Service = Depends()):
    return service.get_by_id(id_)


@<resource>Router.post('/', response_model=<Resource>Response, summary='Create <resource>')
def create_<resource>(data: <Resource>Create, service: <Resource>Service = Depends()):
    return service.create(data)


@<resource>Router.put('/{id_}', response_model=<Resource>Response, summary='Update <resource>')
def update_<resource>(id_: int, data: <Resource>Update, service: <Resource>Service = Depends()):
    return service.update(id_, data)


@<resource>Router.delete('/{id_}', summary='Delete <resource>')
def delete_<resource>(id_: int, service: <Resource>Service = Depends()):
    return service.delete(id_)
```

---

## `tests/conftest.py`

```python
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.database import get_db
from app.models.base import Base
from main import app

TEST_DB_URL = 'sqlite:///./test.db'
engine = create_engine(TEST_DB_URL, connect_args={'check_same_thread': False})
TestingSessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(autouse=True)
def _reset_schema():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield


@pytest.fixture()
def client():
    return TestClient(app)
```

---

## `.env.example`

```
JWT_SECRET_KEY=change-me
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=60

# Sqlite default — replace with a Postgres URL for prod
DATABASE_URL=sqlite:///./app.db
```

---

## `ruff.toml`

```toml
line-length = 100
target-version = "py311"

[lint]
select = ["E", "F", "I", "B", "UP"]
ignore = ["E501", "B008"]

[format]
quote-style = "single"
```
