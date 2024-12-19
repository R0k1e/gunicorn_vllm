import requests
import json
# tokenizer = AutoTokenizer.from_pretrained(args.model_name)

# def build_message(self, prompt, input_dict):

#     message = [{'role': 'user', 'content': prompt.format(**input_dict)}]
#     message_str = self.tokenizer.apply_chat_template(
#         conversation=message, tokenize=False, add_generation_prompt=True)
#     return message_str
      
    
for i in range(5):
    print(f"Request {i}")
    url = "http://localhost:39875/infer"
    data = {"instances": ["hello"], "params": {}}
    result = requests.post(url, json=data, headers={"Content-Type": "application/json"})
    outputs = json.loads(result.content)
    for output in outputs:
        print(output)
