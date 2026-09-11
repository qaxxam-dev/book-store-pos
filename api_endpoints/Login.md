1. Login http Request:

const url = 'https://bookstorepos.alqatech.in/wp-json/pos-shop/v1/login';

const data = `{
    "username": "user@email.com",
    "password": "password@2k24"
}`;

const response = await fetch(url, {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
    },
    body: data,
});

const text = await response.text();

console.log(text);


2. Success Response Example:

{
    "status": "success",
    "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJpc3MiOiJodHRwczpcL1wvYm9va3N0b3JlcG9zLmFscWF0ZWNoLmluIiwiaWF0IjoxNzY0ODYzMzI5LCJleHAiOjE3NjU0NjgxMjl9.N7WgO1FnMnBpstah-odYZXDCS27WnYKglv0ZG6j33LA",
    "user_id": 1,
    "user_email": "alqassamdev@gmail.com",
    "user_display_name": "qassam",
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
    "code": "invalid_credentials",
    "message": "Invalid username or password.",
    "data": {
        "status": 403
    }
}