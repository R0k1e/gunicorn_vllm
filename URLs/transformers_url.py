from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch
from gevent.pywsgi import WSGIServer
import argparse
import threading

parser = argparse.ArgumentParser()
parser.add_argument("--model_name", type=str, help="Model name on hugginface")
parser.add_argument("--port", type=int, default=5002, help="the port")
args = parser.parse_args()

app = Flask(__name__)

print("Initializing model and tokenizer...")

# Set the device to GPU if available
device = "cuda" if torch.cuda.is_available() else "cpu"

# Load the model and tokenizer
model = AutoModelForCausalLM.from_pretrained(args.model_name).to(device)
tokenizer = AutoTokenizer.from_pretrained(args.model_name)

# Check and add pad token if necessary
if tokenizer.pad_token is None:
    tokenizer.add_special_tokens({"pad_token": "[PAD]"})
    model.resize_token_embeddings(len(tokenizer))

print("Model and tokenizer initialized.")


semaphore = threading.Semaphore(1)


@app.route("/infer", methods=["POST"])
def main():
    with semaphore:
        params_dict = {
            "do_sample": True,
            "temperature": 1,
        }
        datas = request.get_json()
        params = datas["params"]
        prompt = datas["instances"]

        for key, value in params.items():
            if key == "max_tokens":
                params_dict["max_new_tokens"] = value
            elif key in params_dict:
                params_dict[key] = value
        if prompt == "":
            return jsonify({"error": "No prompt provided"}), 400

        messages = []
        for p in prompt:
            message = tokenizer.apply_chat_template(
                conversation=p, tokenize=False, add_generation_prompt=True
            )
            messages.append(message)

        inputs = tokenizer(messages, padding=True, return_tensors="pt").to(
            device
        )  # Prepare the input tensor

        generate_ids = model.generate(
            inputs.input_ids, attention_mask=inputs.attention_mask, **params_dict
        )

        # Decoding the generated ids to text
        generated_text = tokenizer.batch_decode(
            generate_ids, skip_special_tokens=True, clean_up_tokenization_spaces=False
        )
        print(prompt)
        print("*********")
        print(generated_text)
        print("*********")
        assert len(prompt) == len(generated_text)
        for j in range(len(prompt)):
            generated_text[j] = generated_text[j][len(prompt[j]) :]
        print(generated_text)
        return jsonify(generated_text)


@app.route("/test", methods=["GET"])
def test():
    return jsonify({"status": "ok"}), 200


if __name__ == "__main__":
    # Run the Flask app
    http_server = WSGIServer(("127.0.0.1", args.port), app)
    http_server.serve_forever()
