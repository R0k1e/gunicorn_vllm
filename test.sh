curl -X POST http://g3005:29667/infer \
    -H "Content-Type: application/json" \
    -d '{
        "params": {
            "temperature": 0.7
        },
        "instances": [
            "This is a test prompt1."
        ]
    }'

curl -X POST http://g3005:29667/infer \
    -H "Content-Type: application/json" \
    -d '{
        "params": {
        },
        "instances": [
            "This is a test prompt2."
        ]
    }'