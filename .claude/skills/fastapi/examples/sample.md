# Worked example: adding a `book` resource

This walk-through shows the exact files Claude should produce when the user says **"add a book resource with title, author, and year"** to a project that already follows this skill's conventions.

Resource singular: `book` · plural: `books` · class: `Book`.

---

## Files created (exactly five + 2 wiring edits)

### 1. `app/models/book.py`

```python
from sqlalchemy import Text
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base, DateTime


class Book(Base, DateTime):
    __tablename__ = 'books'

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(nullable=False)
    author: Mapped[str] = mapped_column(nullable=False)
    year: Mapped[int] = mapped_column(nullable=False)
    summary: Mapped[str] = mapped_column(Text, nullable=True)
    deleted: Mapped[bool] = mapped_column(default=False, nullable=False)
```

### 2. `app/schema/book.py`

```python
from datetime import datetime

from pydantic import BaseModel, Field


class BookCreate(BaseModel):
    title: str
    author: str
    year: int = Field(ge=0, le=9999)
    summary: str | None = None


class BookUpdate(BaseModel):
    title: str | None = None
    author: str | None = None
    year: int | None = Field(default=None, ge=0, le=9999)
    summary: str | None = None


class BookResponse(BaseModel):
    id: int
    title: str
    author: str
    year: int
    summary: str | None = None
    deleted: bool
    created_at: datetime
    updated_at: datetime

    model_config = {'from_attributes': True}
```

### 3. `app/repositories/book.py`

```python
from sqlalchemy import desc
from sqlalchemy.orm import Session

from app.models.book import Book
from app.schema.book import BookCreate, BookUpdate


class BookRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_all(self, skip: int = 0, limit: int = 100) -> list[Book]:
        return (
            self.db.query(Book)
            .filter(Book.deleted.is_(False))
            .order_by(desc(Book.created_at))
            .offset(skip)
            .limit(limit)
            .all()
        )

    def get_by_id(self, book_id: int) -> Book | None:
        return (
            self.db.query(Book)
            .filter(Book.id == book_id, Book.deleted.is_(False))
            .first()
        )

    def search_by_author(self, author: str) -> list[Book]:
        return (
            self.db.query(Book)
            .filter(Book.deleted.is_(False), Book.author.ilike(f'%{author.strip()}%'))
            .order_by(desc(Book.created_at))
            .all()
        )

    def create(self, data: BookCreate) -> Book:
        book = Book(**data.model_dump())
        self.db.add(book)
        self.db.commit()
        self.db.refresh(book)
        return book

    def update(self, book_id: int, data: BookUpdate) -> Book | None:
        book = self.get_by_id(book_id)
        if not book:
            return None
        for key, value in data.model_dump(exclude_unset=True).items():
            setattr(book, key, value)
        self.db.commit()
        self.db.refresh(book)
        return book

    def delete(self, book_id: int) -> Book | None:
        book = self.get_by_id(book_id)
        if not book:
            return None
        book.deleted = True
        self.db.commit()
        return book
```

### 4. `app/services/book.py`

```python
from fastapi import Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.exception import NotFoundException
from app.repositories.book import BookRepository
from app.schema.book import BookCreate, BookResponse, BookUpdate


class BookService:
    def __init__(self, db: Session = Depends(get_db)):
        self.db = db
        self.repository = BookRepository(db=self.db)

    def get_all(self, skip: int = 0, limit: int = 100) -> list[BookResponse]:
        return [
            BookResponse.model_validate(b)
            for b in self.repository.get_all(skip=skip, limit=limit)
        ]

    def get_by_id(self, book_id: int) -> BookResponse:
        book = self.repository.get_by_id(book_id)
        if not book:
            raise NotFoundException(message='Book not found')
        return BookResponse.model_validate(book)

    def search_by_author(self, author: str) -> list[BookResponse]:
        return [
            BookResponse.model_validate(b)
            for b in self.repository.search_by_author(author)
        ]

    def create(self, data: BookCreate) -> BookResponse:
        return BookResponse.model_validate(self.repository.create(data))

    def update(self, book_id: int, data: BookUpdate) -> BookResponse:
        book = self.repository.update(book_id, data)
        if not book:
            raise NotFoundException(message='Book not found')
        return BookResponse.model_validate(book)

    def delete(self, book_id: int) -> dict:
        if not self.repository.delete(book_id):
            raise NotFoundException(message='Book not found')
        return {'message': 'Book deleted'}
```

### 5. `app/routes/book.py`

```python
from fastapi import APIRouter, Depends

from app.schema.book import BookCreate, BookResponse, BookUpdate
from app.services.book import BookService

bookRouter = APIRouter(tags=['books'])


@bookRouter.get('/', response_model=list[BookResponse], summary='List books')
def list_books(skip: int = 0, limit: int = 100, service: BookService = Depends()):
    return service.get_all(skip=skip, limit=limit)


@bookRouter.get('/search', response_model=list[BookResponse], summary='Search books by author')
def search_books(author: str, service: BookService = Depends()):
    return service.search_by_author(author)


@bookRouter.get('/{book_id}', response_model=BookResponse, summary='Get book by id')
def get_book(book_id: int, service: BookService = Depends()):
    return service.get_by_id(book_id)


@bookRouter.post('/', response_model=BookResponse, summary='Create book')
def create_book(data: BookCreate, service: BookService = Depends()):
    return service.create(data)


@bookRouter.put('/{book_id}', response_model=BookResponse, summary='Update book')
def update_book(book_id: int, data: BookUpdate, service: BookService = Depends()):
    return service.update(book_id, data)


@bookRouter.delete('/{book_id}', summary='Delete book')
def delete_book(book_id: int, service: BookService = Depends()):
    return service.delete(book_id)
```

---

## Wiring edits

### `app/routes/__init__.py` — register the router

```python
from fastapi import APIRouter

from .book import bookRouter

RootRouter = APIRouter()
RootRouter.include_router(bookRouter, prefix='/api/books')
```

### `app/db/database.py` — register the model module

Add this line near the other model imports:

```python
import app.models.book  # noqa: F401
```

---

## Migration

```bash
alembic revision --autogenerate -m "add books table"
alembic upgrade head
```

---

## `tests/test_book.py`

```python
def _payload(**overrides):
    base = {'title': 'The Pragmatic Programmer', 'author': 'Hunt', 'year': 1999}
    base.update(overrides)
    return base


def test_create_book_returns_200_and_body(client):
    response = client.post('/api/books/', json=_payload())
    assert response.status_code == 200
    body = response.json()
    assert body['title'] == 'The Pragmatic Programmer'
    assert body['id'] > 0


def test_create_book_validation_error_on_bad_year(client):
    response = client.post('/api/books/', json=_payload(year=-1))
    assert response.status_code == 422


def test_create_book_validation_error_on_missing_required(client):
    response = client.post('/api/books/', json={'title': 'x'})
    assert response.status_code == 422


def test_get_book_404_when_missing(client):
    response = client.get('/api/books/999')
    assert response.status_code == 404
    assert response.json() == {'message': 'Book not found'}


def test_list_books_returns_created_book(client):
    client.post('/api/books/', json=_payload())
    response = client.get('/api/books/')
    assert response.status_code == 200
    assert len(response.json()) == 1


def test_update_book_partial(client):
    created = client.post('/api/books/', json=_payload()).json()
    response = client.put(f'/api/books/{created["id"]}', json={'year': 2000})
    assert response.status_code == 200
    assert response.json()['year'] == 2000


def test_delete_book_soft_deletes(client):
    created = client.post('/api/books/', json=_payload()).json()
    response = client.delete(f'/api/books/{created["id"]}')
    assert response.status_code == 200
    assert response.json() == {'message': 'Book deleted'}
    assert client.get(f'/api/books/{created["id"]}').status_code == 404
```

---

## Commit message

```
feat(book): add CRUD endpoints for books

- model, schema, repository, service, route
- alembic migration
- pytest coverage for happy path, 404, and validation error
```
