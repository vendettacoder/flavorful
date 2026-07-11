import os
from typing import Any
from uuid import UUID

from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel
from supabase import Client, create_client


def get_db_client(auth_header: str):
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=401, detail="Missing or invalid Authorization header"
        )

    token = auth_header.split(" ")[1]

    # Clone client to prevent multi-user token leaking across async requests
    scoped_client = create_client(
        os.getenv("SUPABASE_URL", ""), os.getenv("SUPABASE_KEY", "")
    )
    scoped_client.postgrest.auth(token)
    return scoped_client


class RecipeDto(BaseModel):
    public_url: str
    recipe_json: dict


# Recipes a user may keep unless they have a higher override in user_limits.
DEFAULT_RECIPE_LIMIT = 10


class RecipeDao:
    table: str = "recipe_db"
    limits_table: str = "user_limits"

    def __init__(self, supabase_client: Client):
        self.supabase: Client = supabase_client

    def count_recipes(self) -> int:
        # RLS scopes this to the current user's rows.
        response = (
            self.supabase.table(self.table)
            .select("recipe_id", count="exact")
            .execute()
        )
        return response.count or 0

    def get_user_limit(self) -> int:
        """The current user's recipe cap. Falls back to DEFAULT_RECIPE_LIMIT if
        the user has no override row (or the user_limits table doesn't exist yet)."""
        try:
            response = (
                self.supabase.table(self.limits_table)
                .select("recipe_limit")
                .execute()  # RLS returns only the caller's own row
            )
            if response.data:
                return int(response.data[0]["recipe_limit"])
        except Exception as e:
            print(f"[user_limit] falling back to default: {e}", flush=True)
        return DEFAULT_RECIPE_LIMIT

    def insert(self, recipe_dto: RecipeDto) -> str | None:
        recipe_dto_dict = recipe_dto.model_dump(mode="json")

        data: dict[str, Any] = {
            "public_url": recipe_dto_dict["public_url"],
            "recipe_metadata": recipe_dto_dict["recipe_json"],
        }
        response = self.supabase.table(self.table).insert(data).execute()
        return response.data[0]["recipe_id"]

    def delete(self, public_url: str) -> int:
        response = (
            self.supabase.table(self.table)
            .delete()
            .eq("public_url", public_url)
            .execute()
        )
        return len(response.data)

    def search_recipes(self, query: str) -> list[dict]:
        if not query:
            return self.get_recipes()
        response = (
            self.supabase.table(self.table)
            .select("*")
            .ilike("recipe_metadata->>recipe_name", f"%{query}%")
            .order("is_favorited", desc=True)
            .order("created_at", desc=True)
            .execute()
        )
        if not response.data:
            return []
        return list(response.data)

    def toggle_favorite(self, recipe_id: str) -> bool:
        current = (
            self.supabase.table(self.table)
            .select("is_favorited")
            .eq("recipe_id", recipe_id)
            .single()
            .execute()
        )
        if not current.data:
            raise HTTPException(status_code=404, detail="Recipe not found")

        new_value = not current.data["is_favorited"]

        self.supabase.table(self.table).update({"is_favorited": new_value}).eq("recipe_id", recipe_id).execute()
        return new_value

    def delete_by_id(self, recipe_id: str) -> int:
        response = (
            self.supabase.table(self.table)
            .delete()
            .eq("recipe_id", recipe_id)
            .execute()
        )
        return len(response.data)

    def delete_all(self) -> int:
        """Delete every recipe belonging to the current user. RLS scopes the
        delete to the caller's own rows; the filter is only there to satisfy
        PostgREST's requirement that DELETE carry a WHERE clause."""
        response = (
            self.supabase.table(self.table)
            .delete()
            .not_.is_("recipe_id", "null")
            .execute()
        )
        # Best-effort cleanup of the user's limit override row, if any.
        try:
            (
                self.supabase.table(self.limits_table)
                .delete()
                .not_.is_("recipe_limit", "null")
                .execute()
            )
        except Exception as e:
            print(f"[delete_all] user_limits cleanup skipped: {e}", flush=True)
        return len(response.data)

    def get_recipes(self) -> list[dict]:
        response = (
            self.supabase.table(self.table)
            .select("*")
            .order("is_favorited", desc=True)
            .order("created_at", desc=True)
            .execute()
        )
        if not response.data:
            return []

        return [recipe_json for recipe_json in response.data]  # pyright: ignore[reportReturnType]

    def get_recipe(self, public_url: str) -> dict | None:
        response = (
            self.supabase.table(self.table)
            .select("*")
            .eq("public_url", public_url)
            .execute()
        )
        if not response.data:
            return None

        return response.data[0]  # pyright: ignore[reportReturnType]
