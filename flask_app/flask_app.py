from flask import Flask, request, jsonify
from argparse import ArgumentParser
import requests
import subprocess

app = Flask(__name__)

parser = ArgumentParser()
parser.add_argument("-n", "--name")

@app.route('/get-name', methods=['GET'])
def get_name():
    name = {"name": app.config["name"]}
    return jsonify(name), 200

@app.route('/test-connectivity', methods=['GET'])
def test_connectivity():
    try:
        response = requests.get("https://ipinfo.io/ip", timeout=5)
        response.raise_for_status()  # Ensure we catch any HTTP errors
        ip_address = response.text
        return jsonify(ip_address=ip_address), 200
    except requests.RequestException as e:
        return jsonify(error="Unable to reach the external service", details=str(e)), 503


@app.route('/get-route', methods=['GET'])
def get_default_gateway_linux():
    result = subprocess.run(['ip', 'route', 'list'], capture_output=True, text=True)
    return result.stdout


if __name__ == '__main__':
    args = parser.parse_args()
    app.config["name"] = args.name if args.name else "I have no name"
    app.run(host='0.0.0.0', port=5000)
