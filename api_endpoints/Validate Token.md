1. Validate Token http Request:

const url = 'https://bookstorepos.alqatech.in/wp-json/pos-shop/v1/token/validate';

const response = await fetch(url, {
    method: 'POST',
    headers: {
        'Authorization': 'Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJpc3MiOiJodHRwczpcL1wvYm9va3N0b3JlcG9zLmFscWF0ZWNoLmluIiwiaWF0IjoxNzY0ODU4NTg4LCJleHAiOjE3NjU0NjMzODh9.xzFIU6NwGsNhV-qvK_EJodwJxe3Y6sU-6IKWhjLWq-Q',
        'Content-Type': 'application/json',
        'Content-Length': '0',
    },
});

const text = await response.text();

console.log(text);

2. Success Response Example:

{
    "status": "success",
    "message": "Token is valid.",
    "data": {
        "user_id": 1,
        "iss": "https:\/\/bookstorepos.alqatech.in",
        "iat": 1764863329,
        "exp": 1765468129
    },
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