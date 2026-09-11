1. Update Shop Settings http Request:

const url = 'https://bookstorepos.alqatech.in/wp-json/pos-shop/v1/settings/update';

const data = `{
    "shop_name": "My Shop",
    "shop_email": "shop@example.com",
    "shop_number": "1234567890",
    "shop_address": "123 Main St",
    "thank_you_message": "Thanks for shopping!",
    "ai_api_key": "sk-..."
}`;

const response = await fetch(url, {
    method: 'POST',
    headers: {
        'Authorization': 'Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJpc3MiOiJodHRwczpcL1wvYm9va3N0b3JlcG9zLmFscWF0ZWNoLmluIiwiaWF0IjoxNzY0Nzc5NjM3LCJleHAiOjE3NjUzODQ0Mzd9.lstw53BEvqQ68dSfNkJiaiIfLzq5wJ2BLBlNelbK5C8',
        'Content-Type': 'application/json',
    },
    body: data,
});

const text = await response.text();

console.log(text);

2. Success Response Example:

{
    "status": "updated",
    "message": "Settings updated successfully.",
    "shop_details": {
        "shop_name": "My Shop",
        "shop_email": "shop@example.com",
        "shop_number": "1234567890",
        "shop_address": "123 Main St",
        "thank_you_message": "Thanks for shopping!",
        "ai_api_key": "sk-..."
    }
}

3. Purchase Required Response Example:

{
    "status": "purchase_required",
    "message": "Purchase of product ID 72 is required.",
    "purchase_url": "https:\/\/bookstorepos.alqatech.in\/product\/book-store-pos\/"
}

4. Invalid Account Response Example:

{
    "code": "jwt_invalid_signature",
    "message": "Invalid token signature.",
    "data": {
        "status": 401
    }
}